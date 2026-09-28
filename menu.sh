#!/usr/bin/env bash
# utilmenu launcher — ONE persistent Walker window.
#   Navigation: native Elephant submenus (gen-menus.sh). Search: utilsearch.lua.
#   Open + app-cache refresh; --preload warms cache + service without GUI.
set -euo pipefail
export GDK_BACKEND=wayland
export PATH="$HOME/.local/bin:$PATH"  # elephant liegt dort (NixOS: nicht im system-PATH)
source "${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2/menu.conf.sh"

APPS_REFRESH() {
  { for d in ~/.local/share/applications /run/current-system/sw/share/applications ~/.nix-profile/share/applications /usr/share/applications; do
      [[ -d "$d" ]] || continue
      for f in "$d"/*.desktop; do
        [[ -f "$f" ]] || continue
        awk -F= '/^(NoDisplay|Hidden)=true/{skip=1} /^Name=/&&!name{name=substr($0,6)} /^Icon=/{icon=substr($0,6)} END{if(!skip && name) printf " \t%s\t%s\t%s\n", name, FILENAME, icon}' "$f"
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
