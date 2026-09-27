#!/usr/bin/env bash
# utilmenu launcher — ONE persistent Walker window over the Elephant menu backend.
#
#   Elephant: menus provider reads menus/utilmenu.lua (state = navstack,
#             GetEntries("") = children, GetEntries(query) = global search).
#   Walker:   dedicated Set "utilmenu" exposes ONLY that provider (see
#             walker/config-snippet.toml). Navigation actions use ClearReload,
#             so Walker re-queries Elephant instead of closing/reopening.
#
# No walker --dmenu anywhere: that path is what forced close->reopen per level
# and stdin-only filtering until Enter. This script is just open + cache.
set -euo pipefail
export GDK_BACKEND=wayland
export PATH="$HOME/.local/bin:$PATH"  # elephant liegt dort (NixOS: nicht im system-PATH)
source "${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2/menu.conf.sh"

APPS_REFRESH() {
  { for d in ~/.local/share/applications /run/current-system/sw/share/applications ~/.nix-profile/share/applications /usr/share/applications; do
      [[ -d "$d" ]] || continue
      for f in "$d"/*.desktop; do
        [[ -f "$f" ]] || continue
        awk -F= '/^(NoDisplay|Hidden)=true/{skip=1} /^Name=/{name=substr($0,6)} END{if(!skip && name) printf " \t%s\t%s\n", name, FILENAME}' "$f"
      done
    done | sort -fu -t$'\t' -k2,2
  } > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

APPS_NEED() { # Refresh nur wenn .desktop-Dirs neuer als Cache
  [[ -f "$CACHE" ]] || return 0
  local d
  for d in ~/.local/share/applications /run/current-system/sw/share/applications ~/.nix-profile/share/applications; do
    [[ -d "$d" && "$d" -nt "$CACHE" ]] && return 0
  done
  return 1
}

case "${1:-}" in
  --preload) # Cold-Start ohne GUI: Cache + Service im Hintergrund, kein Fenster
    APPS_NEED && APPS_REFRESH
    pgrep -f "walker --gapplication-service" >/dev/null || (walker --gapplication-service &>/dev/null & disown)
    exit 0
    ;;
esac

APPS_NEED && APPS_REFRESH
pgrep -f "walker --gapplication-service" >/dev/null || (walker --gapplication-service &>/dev/null & disown)

exec walker --set utilmenu --width "$WW" --height "$HH"
