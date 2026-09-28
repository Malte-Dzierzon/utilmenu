#!/usr/bin/env bash
# Wendet ein Animations-Preset an: ersetzt animations-Block in niri config.kdl.
set -euo pipefail
PRESET="${1:?preset name}"
SRC="$HOME/.config/utilmenu2/niri-anims/$PRESET.kdl"
CFG="$HOME/.config/niri/config.kdl"
[[ -f "$SRC" ]] || { notify-send "Anim-Preset fehlt: $PRESET"; exit 1; }
cp "$CFG" "$CFG.bak-anim-$(date +%s)"
python3 - "$SRC" "$CFG" <<'PY'
import re, sys
src = open(sys.argv[1]).read().rstrip() + "\n"
path = sys.argv[2]
cfg = open(path).read()
pat = re.compile(r'^animations \{.*?\n\}\n', re.M | re.S)
assert pat.search(cfg), "animations block not found"
open(path, "w").write(pat.sub(src, cfg, count=1))
PY
niri validate 2>&1 | tail -1
notify-send "Niri-Animation: $PRESET"
