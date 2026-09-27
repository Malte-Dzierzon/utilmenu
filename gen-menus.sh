#!/usr/bin/env bash
# Generiert native Elephant-TOML-Menüs aus menu.conf. Nativer submenu-Mechanismus:
# Kategorie -> eigenes Menü, Entry mit submenu="utilmenu_<id>", Walker menus:open navigiert.
set -euo pipefail
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2/menu.conf"
OUT="${XDG_CONFIG_HOME:-$HOME/.config}/elephant/menus"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/utilmenu-apps.list"
declare -A LABEL=() PARENT=() HANDLER=() HEX=()
IDS=()
while IFS='|' read -r kind id parent hex label handler alias desc; do
  [[ "$kind" == action ]] || continue
  [[ -z "$id" ]] && continue
  LABEL["$id"]="$label"; PARENT["$id"]="${parent:-root}"; HANDLER["$id"]="$handler"; HEX["$id"]="$hex"
  IDS+=("$id")
done < <(grep -v '^#' "$CONF" | grep -v '^$')
declare -A HEXCACHE=()
while IFS=: read -r hx ch; do HEXCACHE["$hx"]="$ch"; done < <(grep -v '^#' "$CONF" | grep -v '^$' | cut -d'|' -f4 | sort -u | python3 -c "
import sys
for line in sys.stdin:
    hx = line.strip() or '0'
    try: print(hx + ':' + chr(int(hx, 16)))
    except Exception: print(hx + ':•')
")
hexchar() { printf '%s' "${HEXCACHE[$1]:-•}"; }
declare -A HAS_KIDS=()
for id in "${IDS[@]}"; do HAS_KIDS["${PARENT[$id]}"]=1; done
is_cat() { [[ -n "${HAS_KIDS[$1]:-}" ]] || [[ "${HANDLER[$1]}" == submenu:* ]]; }
entry_for() { # $1 = id -> TOML-Block
  local id="$1" ic
  ic="$(hexchar "${HEX[$id]:-0}")"
  if is_cat "$id"; then
    printf '[[entries]]\ntext = "%s"\nicon = "%s"\nsubmenu = "utilmenu_%s"\n' "${LABEL[$id]}" "$ic" "$id"
  else
    local act="${HANDLER[$id]#run:}"
    printf '[[entries]]\ntext = "%s"\nicon = "%s"\nactions = { default = "bash $HOME/.config/utilmenu2/actions.d/%s" }\n' "${LABEL[$id]}" "$ic" "$act"
  fi
}
{ echo 'name = "utilmenu"'; echo 'name_pretty = "Utilmenu"'; echo 'fixed_order = true'
  for id in "${IDS[@]}"; do [[ "${PARENT[$id]}" == root ]] || continue; echo; entry_for "$id"; done
} > "$OUT/utilmenu.toml"
for cat in "${IDS[@]}"; do
  is_cat "$cat" || continue
  { echo "name = \"utilmenu_$cat\""; echo "name_pretty = \"${LABEL[$cat]}\""; echo 'parent = "utilmenu"'; echo 'fixed_order = true'
    for id in "${IDS[@]}"; do [[ "${PARENT[$id]}" == "$cat" ]] || continue; echo; entry_for "$id"; done
    if [[ "$cat" == apps && -f "$CACHE" ]]; then
      while IFS=$'\t' read -r _sp name file icon; do
        [[ -n "$name" && -n "$file" ]] || continue
        if [[ -n "$icon" ]]; then
          printf '\n[[entries]]\ntext = "%s"\nicon = "%s"\nactions = { default = "gtk-launch %s" }\n' "$name" "$icon" "$(basename "$file" .desktop)"
        else
          printf '\n[[entries]]\ntext = "%s"\nactions = { default = "gtk-launch %s" }\n' "$name" "$(basename "$file" .desktop)"
        fi
      done < "$CACHE"
    fi
  } > "$OUT/utilmenu_$cat.toml"
done
echo "GENERATED: $(ls "$OUT"/utilmenu*.toml | wc -l) Menüs"
