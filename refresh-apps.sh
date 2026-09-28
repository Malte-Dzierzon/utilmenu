#!/usr/bin/env bash
# Baut den App-Cache neu (gleiche Logik wie menu.sh APPS_REFRESH).
set -euo pipefail
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/utilmenu-apps.list"
{
for d in ~/.local/share/applications /run/current-system/sw/share/applications ~/.nix-profile/share/applications /usr/share/applications; do
  [[ -d "$d" ]] || continue
  for f in "$d"/*.desktop; do
    [[ -f "$f" ]] || continue
    awk -F= '/^(NoDisplay|Hidden)=true/{skip=1} /^Name=/&&!name{name=substr($0,6)} /^Icon=/{icon=substr($0,6)} END{if(!skip && name) printf " \t%s\t%s\t%s\n", name, FILENAME, icon}' "$f"
  done
done | sort -fu -t$'\t' -k2,2
} > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
