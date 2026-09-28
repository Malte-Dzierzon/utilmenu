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
lines = cfg.splitlines(keepends=True)
start = next(i for i, l in enumerate(lines) if l.startswith("animations {"))
# r"-Shader maskieren (GLSL-Braces nicht zählen)
def masked(ls):
    out, in_raw = [], False
    for l in ls:
        if not in_raw and 'custom-shader r"' in l:
            in_raw = True
            out.append(l.split('r"')[0])
        elif in_raw and l.strip() == '"':
            in_raw = False
            out.append("")
        elif in_raw:
            out.append("")
        else:
            out.append(l)
    return out
m = masked(lines)
depth, end = 0, None
for i in range(start, len(lines)):
    depth += m[i].count("{") - m[i].count("}")
    if depth == 0:
        end = i
        break
assert end is not None, "animations block not balanced"
open(path, "w").write("".join(lines[:start]) + src + "".join(lines[end + 1:]))
PY
niri validate 2>&1 | tail -1
notify-send "Niri-Animation: $PRESET"
