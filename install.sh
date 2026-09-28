#!/usr/bin/env bash
# utilmenu installer — idempotent, user-scope only ($HOME + user systemd).
# Overwrites nothing outside utilmenu paths except MERGING the walker snippet.
# Usage: ./install.sh [--no-services] [--keybind]
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/utilmenu2"
ELEPHANT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/elephant/menus"
WALKER_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/walker/config.toml"

need() { command -v "$1" >/dev/null || { echo "MISSING: $1" >&2; return 1; }; }
missing=0
need walker || missing=1
need elephant || { echo "HINT: add 'elephant' to environment.systemPackages + nixos-rebuild switch"; missing=1; }
need foot || echo "WARN: foot missing (TUI launches need it)"
[[ $missing == 0 ]] || { echo "ABORT: install requirements first"; exit 1; }

mkdir -p "$DEST/actions.d" "$ELEPHANT_DIR" ~/.config/walker ~/.config/systemd/user
cp "$REPO/menu.sh" "$REPO/menu.conf" "$REPO/menu.conf.sh" \
   "$REPO/gen-menus.sh" "$REPO/sync-style.sh" \
   "$REPO/recolor-icons.sh" "$REPO/recolor.py" "$DEST/"
cp "$REPO/actions.d/"* "$DEST/actions.d/"
mkdir -p "$DEST/elephant"
cp "$REPO/elephant/submenu.lua" "$DEST/elephant/submenu.lua"
chmod +x "$DEST/"*.sh "$DEST/actions.d/"*
cp "$REPO/elephant/menus/utilsearch.lua" "$ELEPHANT_DIR/utilsearch.lua"

"$DEST/gen-menus.sh"
"$DEST/sync-style.sh" || true
"$DEST/recolor-icons.sh" || true

# walker snippet: merge set/actions/placeholders/theme only if absent
touch "$WALKER_CONF"
for key in 'theme = "noctalia"' '[providers.sets.utilmenu]' '[placeholders."menus:utilmenu"]'; do
  grep -qF "$key" "$WALKER_CONF" || { echo "MERGE: $key missing — append from: $REPO/walker/config-snippet.toml"; }
done
python3 - "$REPO/walker/config-snippet.toml" "$WALKER_CONF" <<'PYEOF'
import sys, tomllib
snippet = open(sys.argv[1], 'rb').read().decode()
live_path = sys.argv[2]
live = open(live_path).read()
changed = False
# ensure theme line
if 'theme = "noctalia"' not in live:
    live = 'theme = "noctalia"\n' + live
    changed = True
open(live_path, 'w').write(live)
try:
    tomllib.loads(open(live_path, 'rb').read().decode())
    print("walker config: TOML valid")
except Exception as e:
    print(f"walker config INVALID after merge attempt: {e}")
    sys.exit(1)
PYEOF
echo "NOTE: review $WALKER_CONF — merge [providers.sets.utilmenu] + [providers.actions] from walker/config-snippet.toml if not present."

if [[ "${1:-}" != "--no-services" ]]; then
  cp "$REPO/systemd/"*.service "$REPO/systemd/"*.path ~/.config/systemd/user/ 2>/dev/null || true
  systemctl --user daemon-reload
  systemctl --user enable --now utilmenu-preload.service 2>/dev/null || echo "WARN: preload service failed"
  systemctl --user enable --now utilmenu-theme.path 2>/dev/null || echo "WARN: theme watcher failed"
  systemctl --user restart elephant 2>/dev/null || echo "WARN: elephant restart failed (start it manually)"
fi

if [[ "${1:-}" == "--keybind" ]]; then
  echo 'Add to niri binds (adjust to taste):'
  echo '  Mod+Space hotkey-overlay-title="Utility Menu" { spawn "'"$DEST"'/menu.sh"; }'
fi

echo "OK: utilmenu installed to $DEST"
