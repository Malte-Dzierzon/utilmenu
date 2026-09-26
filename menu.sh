#!/usr/bin/env bash
# utilmenu v2 — ONE global dataset, generic parent navigation, global search.
# Architektur: ein Walker-Service-Fenster (warm via --gapplication-service,
# gehalten mit -k), Inhalt = Projektion des globalen Datensatzes:
#   leerer Query  -> direkte Kinder von current_parent (nav_rows)
#   Query gesetzt -> globale Suche ueber alle SEARCHABLE=1 (search_rows)
# Navigation: submenu:<id> setzt current_parent; Back geht zum Parent.
# Hinweis: echtes In-Place-Update ohne Prozessneustart braucht den
# Elephant-menus-Provider (hier nicht installiert); bis dahin ist dies
# das naechstkorrekte Modell: ein warmes Service-Fenster, ein Datensatz,
# keine Sonderfaelle pro Kategorie.
set -euo pipefail
export GDK_BACKEND=wayland
source "${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2/menu.conf.sh"

# ---------- Ein globaler Datensatz ----------
declare -A GLYPH=() LABEL=() HANDLER=() PARENT=() ALIAS=() DESC=() ORDER=() SEARCHABLE=()
declare -A CHILDREN=()  # parent_id -> "id id ..."
order=0
while IFS='|' read -r kind id parent hex label handler alias desc; do
  [[ "$kind" == \#* || -z "$kind" || "$kind" != action ]] && continue
  parent="${parent:-root}"
  PARENT["$id"]="$parent"
  LABEL["$id"]="$label"
  _uc=$(printf "%08X" "0x$hex")
  GLYPH["$id"]="$(printf "\U$_uc")"
  HANDLER["$id"]="${handler:-}"
  ALIAS["$id"]="${alias:-}"
  DESC["$id"]="${desc:-}"
  if [[ "$parent" == root ]]; then SEARCHABLE["$id"]=0; else SEARCHABLE["$id"]=1; fi
  CHILDREN["$parent"]+=" $id"
  ORDER["$id"]=$order
  ((++order))
done < "$DIR/menu.conf"

# ---------- Projektion: Navigation = Kinder von current_parent ----------
declare -a ROWIDS=()
declare -A IDMAP=()
children_of() { # $1 = parent -> ids in ORDER
  local ids="${CHILDREN[$1]:-}" c
  for c in $ids; do [[ -n "$c" ]] && echo "${ORDER[$c]:-0} $c"; done | sort -n | cut -d' ' -f2-
}
nav_rows() { # $1 = parent
  ROWIDS=(); IDMAP=()
  local c
  if [[ "$1" != root ]]; then
    IDMAP["Zurück"]=__back
    printf '\U000F060\tZurück\n'
  fi
  for c in $(children_of "$1"); do
    ROWIDS+=("$c")
    IDMAP["${LABEL[$c]}"]="$c"
    printf '%s\t%s\n' "${GLYPH[$c]:-•}" "${LABEL[$c]}"
  done
  if [[ "$1" == apps ]]; then
    while IFS=$'\t' read -r _sp name file; do
      ROWIDS+=("desk:$file"); IDMAP["$name"]="desk:$file"
      printf ' \t%s\n' "$name"
    done < "$CACHE"
  fi
}

# ---------- Projektion: globale Suche (SEARCHABLE=1 + Apps), Pfad als Subtext ----------
path_of() { # breadcrumb "Style › Themes" (ohne Blatt, ohne root)
  local x="$1" parts=()
  while [[ -n "${PARENT[$x]:-}" && "${PARENT[$x]}" != root ]]; do
    x="${PARENT[$x]}"; parts=("${LABEL[$x]:-$x}" "${parts[@]}")
  done
  local IFS=' › '; echo "${parts[*]}"
}
search_rows() { # $1 = query
  ROWIDS=(); IDMAP=()
  local ql="${1,,}" m scored
  scored="$(for m in "${!LABEL[@]}"; do
    [[ "${SEARCHABLE[$m]:-1}" == 1 ]] || continue
    match=0
    for term in $ql; do
      [[ -z "$term" ]] && continue
      hay="${LABEL[$m]:-} ${ALIAS[$m]:-} ${m##*.} ${DESC[$m]:-}"
      [[ "${hay,,}" == *"$term"* ]] && match=1 || { match=0; break; }
    done
    [[ $match == 1 ]] || continue
    s=30; [[ "${LABEL[$m],,}" == "$ql"* ]] && s=10
    echo "$s ${ORDER[$m]:-0} $m"
  done | sort -n | cut -d' ' -f3-)" || true
  for m in $scored; do
    ROWIDS+=("$m"); IDMAP["${LABEL[$m]}"]="$m"
    printf '%s\t%s\t%s\n' "${GLYPH[$m]:-•}" "${LABEL[$m]}" "$(path_of "$m")"
  done
  while IFS=$'\t' read -r _sp name file; do
    [[ "${name,,}" == *"$ql"* ]] || continue
    ROWIDS+=("desk:$file"); IDMAP["$name"]="desk:$file"
    printf ' \t%s\tApps\n' "$name"
  done < "$CACHE"
}

# ---------- Walker: ein warmes Service-Fenster ----------
walker_pick() { # $1 = placeholder; liest Zeilen von stdin
  walker --dmenu -k -e -p "${1:-Search}" -t "$THEME" --width "$WW" --height "$HH"
}

# ---------- Apps-Cache ----------
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
    active=root; navstack=(); continue
  fi
  label="${sel#*$'\t'}"; label="${label%%$'\t'*}"
  selid="${IDMAP[$label]:-}"
  if [[ -z "$selid" ]]; then query="$label"; continue; fi  # Walker-Live-Filter ohne Treffer -> globale Suche
  query=""
  case "$selid" in
    __back)
      if ((${#navstack[@]})); then active="${navstack[-1]}"; unset 'navstack[-1]'
      else active=root; fi
      continue ;;
    desk:*)
      file="${selid#desk:}"; file="${file%%::*}"
      term=false; grep -q -m1 "^Terminal=true" "$file" && term=true
      exec="$(grep -m1 '^Exec=' "$file" | cut -d= -f2- | sed 's/ %[fFuUick]//g')"
      if [[ "$term" == true ]]; then setsid foot bash -lc "$exec; read -rp 'Enter ' _" & disown
      else eval "setsid $exec" & disown; fi
      exit 0 ;;
    *)
      h="${HANDLER[$selid]:-}"
      case "$h" in
        submenu:*) navstack+=("$active"); active="${h#submenu:}"; continue ;;
        run:*) bash "$DIR/actions.d/$selid" & disown; exit 0 ;;
        *) # ohne Handler + Kinder = Kategorie -> generisch navigieren
          if [[ -n "${CHILDREN[$selid]:-}" ]]; then navstack+=("$active"); active="$selid"; continue; fi
          notify-send "utilmenu" "Später: ${LABEL[$selid]:-$selid}" & disown; exit 0 ;;
      esac ;;
  esac
done
