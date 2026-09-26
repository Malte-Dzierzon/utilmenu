#!/usr/bin/env bash
# utilmenu v2 — Flat global entries, hierarchical navigation, global search
# Single-Window-Gefuehl via Walker-Service (warm, kein GTK-Coldstart).
# TUI-Apps: Floating NUR fuer about / btop / wiremix.
set -euo pipefail
export GDK_BACKEND=wayland
source "${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2/menu.conf.sh"

# ---------- Global Data ----------
declare -A GLYPH=() LABEL=() HANDLER=() PARENT=() ALIAS=() DESC=() ORDER=() KIND=() SEARCHABLE=()
declare -A ROOT_CHILDREN=()  # parent_id -> ordered list of child ids

# Parse config: flat global entries with explicit parent_id
cur_menu=""
order=0
while IFS='|' read -r kind id parent hex label handler alias desc; do
  [[ "$kind" == \#* || -z "$kind" ]] && continue
  if [[ "$kind" == menu ]]; then
    cur_menu="$id"
    parent="${parent:-root}"
    PARENT["$id"]="$parent"
    LABEL["$id"]="$label"
    _uc=$(printf "%08X" "0x$hex")
    GLYPH["$id"]="$(printf "\U$_uc")"
    KIND["$id"]=cat
    SEARCHABLE["$id"]=0
    # menu entries are just container declarations, NOT visible entries
  elif [[ "$kind" == action ]]; then
    parent="${parent:-$cur_menu}"
    parent="${parent:-root}"
    PARENT["$id"]="$parent"
    LABEL["$id"]="$label"
    _uc=$(printf "%08X" "0x$hex")
    GLYPH["$id"]="$(printf "\U$_uc")"
    HANDLER["$id"]="$handler"
    ALIAS["$id"]="${alias:-}"
    DESC["$id"]="${desc:-}"
    # Root categories (parent=root) are NOT searchable
    if [[ "$parent" == root ]]; then
      SEARCHABLE["$id"]=0
      KIND["$id"]=cat
    else
      SEARCHABLE["$id"]=1
      KIND["$id"]=leaf
    fi
    ROOT_CHILDREN["$parent"]+=" $id"
    ORDER["$id"]=$order
    ((++order))
  fi
done < "$DIR/menu.conf"

# Ensure root has correct order for the 8 main categories
# (ROOT_CHILDREN[root] already populated in declaration order)

# ---------- Helpers ----------
# Get direct children of a parent, ordered by ORDER
children_of() {
  local parent="$1"
  local children="${ROOT_CHILDREN[$parent]:-}"
  local child ordered=""
  for child in $children; do
    [[ -z "$child" ]] && continue
    ordered+="${ORDER[$child]:-0} $child\n"
  done
  echo -e "$ordered" | sort -n | cut -d" " -f2-
}

# ---------- Apps ----------
APPS_REFRESH() {
  { local d f name
    for d in ~/.local/share/applications /run/current-system/sw/share/applications ~/.nix-profile/share/applications /usr/share/applications; do
      [[ -d "$d" ]] || continue
      for f in "$d"/*.desktop; do
        [[ -f "$f" ]] || continue
        grep -q -E '^(NoDisplay|Hidden)=true' "$f" && continue
        name="$(grep -m1 '^Name=' "$f" | cut -d= -f2-)" || continue
        [[ -n "$name" ]] || continue
        printf ' \t%s\t%s\n' "$name" "$f"
      done
    done | sort -fu -t$'\t' -k2,2
  } > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

# ---------- Navigation & Search ----------
declare -a ROWIDS=()
declare -A IDMAP=()

# Navigation: visible projection = direct children of current_parent
nav_rows() { # $1 = parent
  ROWIDS=(); IDMAP=()
  local child
  if [[ "$1" == root ]]; then
    for child in $(children_of root); do
      ROWIDS+=("$child")
      IDMAP["${LABEL[$child]:-$child}"]="$child"
      printf '%s\t%s\n' "${GLYPH[$child]:-•}" "${LABEL[$child]:-$child}"
    done
    return 0
  fi
  # Back entry
  IDMAP["Zurück"]=__back
  printf '\U000F060\tZurück\n'
  for child in $(children_of "$1"); do
    ROWIDS+=("$child")
    IDMAP["${LABEL[$child]}"]="$child"
    printf '%s\t%s\n' "${GLYPH[$child]:-•}" "${LABEL[$child]}"
  done
  # Apps gets desktop apps appended
  if [[ "$1" == apps ]]; then
    while IFS=$'\t' read -r _sp name file; do
      ROWIDS+=("desk:$file")
      IDMAP["$name"]="desk:$file"
      printf ' \t%s\n' "$name"
    done < "$CACHE"
  fi
}

# Search: ALL entries with SEARCHABLE==1 + Desktop-Apps, independent of context
name_text() { # label + alias + leafId
  local leaf="${1##*.}"
  echo "${LABEL[$1]:-} ${ALIAS[$1]:-} ${leaf,,}"
}
matches_query() { # all terms in nameText OR desc-word
  local q="${5,,}" term
  for term in $q; do
    [[ -z "$term" ]] && continue
    [[ "${1,,}" == *"$term"* || "${2,,}" == *"$term"* || "${3,,}" == *"$term"* ]] && continue
    [[ " ${4,,} " == *" $term "* ]] && continue
    return 1
  done
  return 0
}
search_score() {
  local needle="${5,,}" label="${2,,}" score=80
  if [[ "$label" == "$needle" ]]; then score=$(( ${3} == menu ? 2 : 0 ))
  elif [[ "$label" == "$needle"* ]]; then score=10
  elif [[ "$label" == *"$needle"* ]]; then score=30
  elif [[ "${1,,}" == *"$needle"* ]]; then score=40
  elif [[ " ${4,,} " == *" $needle "* ]]; then score=60
  fi
  [[ "$3" == menu || "$3" == link ]] && ((score-=2))
  [[ "$3" == app ]] && ((score-=5))
  echo $(( score * 1000 + ${6:-0} * 25 + ${7:-0} ))
}
depth_of() { local x="$1" d=0; while [[ -n "${PARENT[$x]:-}" && "${PARENT[$x]}" != root ]]; do x="${PARENT[$x]}"; ((++d)); done; echo $d; }

search_rows() { # $1 = query
  ROWIDS=(); IDMAP=()
  local m scored leaf
  scored="$(for m in "${!LABEL[@]}"; do
    [[ "${SEARCHABLE[$m]:-1}" == 1 ]] || continue
    matches_query "${ALIAS[$m]:-}" "${LABEL[$m]:-}" "$m" "${DESC[$m]:-}" "$1" || continue
    leaf="${m##*.}"
    echo "$(search_score "${ALIAS[$m]:-}" "${LABEL[$m]:-}" "${KIND[$m]:-leaf}" "${DESC[$m]:-}" "$1" "${ORDER[$m]:-0}" "$(depth_of "$m")") $m"
  done | sort -n | cut -d' ' -f2-)" || true
  for m in $scored; do
    ROWIDS+=("$m")
    IDMAP["${LABEL[$m]}"]="$m"
    printf '%s\t%s\n' "${GLYPH[$m]:-•}" "${LABEL[$m]}"
  done
  local ql="${1,,}"
  while IFS=$'\t' read -r _sp name file; do
    [[ "${name,,}" == *"$ql"* ]] || continue
    ROWIDS+=("desk:$file")
    IDMAP["$name"]="desk:$file"
    printf ' \t%s\n' "$name"
  done < "$CACHE"
}

# ---------- Walker (Service-warm, kein Coldstart) ----------
walker_pick() {
  walker --dmenu -k -e -p "${1:-Search}" -t "$THEME" --width "$WW" --height "$HH"
}

# ---------- Init ----------
[[ -f "$CACHE" ]] || APPS_REFRESH
pgrep -f "walker --gapplication-service" >/dev/null || (walker --gapplication-service &>/dev/null & disown)
( sleep 2; APPS_REFRESH ) & disown 2>/dev/null

LF="$(mktemp)"; trap 'rm -f "$LF"' EXIT
active=root
query=""
navstack=()

while true; do
  if [[ -n "$query" ]]; then search_rows "$query" > "$LF"; else nav_rows "$active" > "$LF"; fi
  case "$active" in
    root) ph="Go…";;
    apps) ph="Apps…";;
    *) ph="${LABEL[$active]:-$active}…";;
  esac
  [[ -n "$query" ]] && ph="Search: $query"
  sel="$(walker_pick "$ph" < "$LF")" || exit 0
  if [[ -z "$sel" ]]; then
    if [[ -n "$query" ]]; then query=""; continue; fi
    [[ "$active" == root ]] && exit 0
    active=root
    navstack=()
    continue
  fi
  label="${sel#*$'\t'}"
  label="${label%%$'\t'*}"
  selid="${IDMAP[$label]:-}"
  if [[ -z "$selid" ]]; then
    query="$label"
    continue
  fi
  query=""
  case "$selid" in
    __back)
      if ((${#navstack[@]})); then
        active="${navstack[-1]}"
        unset 'navstack[-1]'
      else
        active=root
      fi
      continue
      ;;
    desk:*)
      file="${selid#desk:}"
      file="${file%%::*}"
      term=false
      grep -q -m1 "^Terminal=true" "$file" && term=true
      exec="$(grep -m1 '^Exec=' "$file" | cut -d= -f2- | sed 's/ %[fFuUick]//g')"
      if [[ "$term" == true ]]; then
        case " $selid " in
          *" btop|"*|*" wiremix|"*) setsid foot -a float-term bash -lc "$exec; read -rp 'Enter ' _" & disown ;;
          *) setsid foot bash -lc "$exec; read -rp 'Enter ' _" & disown ;;
        esac
      else
        eval "setsid $exec" & disown
      fi
      exit 0
      ;;
    *)
      m="$selid"
      h="${HANDLER[$m]:-}"
      case "$h" in
        submenu:*)
          navstack+=("$active")
          active="${h#submenu:}"
          continue
          ;;
        run:*)
          bash "$DIR/actions.d/$m" & disown
          exit 0
          ;;
        *)
          if [[ "${KIND[$m]:-leaf}" == cat ]]; then
            navstack+=("$active")
            active="$m"
            continue
          fi
          notify-send "utilmenu" "Später: ${LABEL[$m]:-$m}" & disown
          exit 0
          ;;
      esac
      ;;
  esac
done