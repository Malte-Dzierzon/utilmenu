#!/usr/bin/env bash
# Färbt App-Icons auf Noctalias app_icon_color um (wie shell.app_icon_colorize).
# Quelle: Noctalia settings.toml (app_icon_color-Rolle -> M3-Palette) + .desktop-Icons.
# Output: ~/.cache/utilmenu-icons/<name>.png (recolored), Cache-Key enthält Farbe.
set -euo pipefail
SET=~/.local/state/noctalia/settings.toml
PAL=~/.cache/noctalia/starship-palette.toml
OUTDIR=~/.cache/utilmenu-icons
ROLE=$(grep -m1 -E '^\s*app_icon_color\s*=' "$SET" | sed -E 's/.*=\s*//;s/[",]//g' | awk '{print $1}'); ROLE=${ROLE:-error}
case "$ROLE" in error) KEY=red;; primary) KEY=green;; secondary) KEY=yellow;; tertiary) KEY=blue;; *) KEY="$ROLE";; esac
COLOR=$(grep -m1 -E "^$KEY\s*=" "$PAL" | sed -E 's/.*"(#[0-9a-fA-F]+)".*/\1/'); COLOR=${COLOR:-#ffb4ab}
[[ "$COLOR" == "#"* ]] || { echo "SKIP: keine Farbe"; exit 0; }
mkdir -p "$OUTDIR"
echo "$COLOR" > "$OUTDIR/.color"
PYENV=/nix/store/1q49gzza3na739r88viy50pzhzpb8yqf-python3-3.13.15-env/bin/python3
export PATH="/nix/store/7gc51gg9j9721gkrphm5qkhcwzm02yg4-librsvg-2.62.3/bin:$PATH"
if [[ -x "$PYENV" ]]; then "$PYENV" "$HOME/.config/utilmenu2/recolor.py" "$COLOR" "$OUTDIR" 2>&1 | tail -2
else nix-shell -p "python3.withPackages (ps: [ps.pillow])" -p librsvg --run "python3 $HOME/.config/utilmenu2/recolor.py $COLOR $OUTDIR" 2>&1 | tail -2; fi
