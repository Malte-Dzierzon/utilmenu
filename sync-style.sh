#!/usr/bin/env bash
# Liest echte Noctalia-Werte (settings.toml + generierte M3-Palette) -> Walker-CSS.
# Noctalia bleibt READ-ONLY: nur Lesen, Schreiben nur eigene style.css.
set -euo pipefail
SET=~/.local/state/noctalia/settings.toml
PAL=~/.cache/noctalia/starship-palette.toml
[[ -f "$SET" && -f "$PAL" ]] || { echo "SKIP: Noctalia-Quelle fehlt, CSS bleibt"; exit 0; }
OUT=~/.config/walker/themes/noctalia/style.css
val() { grep -m1 -E "^\s*$1\s*=" "$SET" | sed -E 's/.*=\s*//;s/[",]//g' | awk '{print $1}'; }
pal() { grep -m1 -E "^$1\s*=" "$PAL" | sed -E 's/.*"(#[0-9a-fA-F]+)".*/\1/'; }
RADIUS=$(val corner_radius_scale); RADIUS=${RADIUS:-0.0}
BAR_OP=$(val background_opacity); BAR_OP=${BAR_OP:-0.47}
FONT=$(grep -m1 -E '^\s*font_family' "$SET" | sed -E 's/.*"\s*//;s/".*//'); FONT=${FONT:-JetBrainsMono NFM}
BASE=$(pal base); SURF=$(pal surface0); TXT=$(pal text); ACC=$(pal green); MUT=$(pal subtext0)
BASE=${BASE:-#131314}; SURF=${SURF:-#1b1b1c}; TXT=${TXT:-#e4e2e3}; ACC=${ACC:-#bbc8d7}; MUT=${MUT:-#8e9196}
# radius_scale 0.0 -> eckig; sonst skaliert (Noctalia-Logik: scale * basis)
px() { python3 -c "print(int(float('$1')*12))" 2>/dev/null || echo 0; }
R=$(px "$RADIUS")
[[ -f "$OUT" ]] && cp "$OUT" "$OUT.bak"
cat > "$OUT" <<EOF
/* utilmenu — generiert aus echter Noctalia-Config. NICHT hand-editieren, sync-style.sh laufen lassen.
   Quelle: settings.toml (radius_scale=$RADIUS bar_opacity=$BAR_OP font=$FONT) + M3-Palette (wallpaper). */
@define-color m_base $BASE;
@define-color m_surface $SURF;
@define-color m_text $TXT;
@define-color m_accent $ACC;
@define-color m_muted $MUT;

* { all: unset; }

.box-wrapper {
  background: alpha(@m_base, 0.82);
  padding: 12px;
  border-radius: ${R}px;
  border: 1px solid alpha(@m_text, 0.35);
}

.input {
  caret-color: @m_text;
  background: alpha(@m_base, 0.55);
  padding: 8px 10px;
  color: @m_text;
  border-radius: 0px;
  border: 1px solid alpha(@m_text, 0.45);
  font-family: "$FONT";
  font-size: 14px;
}
.input placeholder { color: alpha(@m_muted, 0.8); }

.list { color: @m_text; margin-top: 6px; }

.item-box {
  border-radius: 0px;
  padding: 7px 10px;
  border: none;
  transition: background 120ms ease-out;
}

child:selected .item-box,
row:selected .item-box {
  background: alpha(@m_accent, 0.35);
  transition: background 120ms ease-out;
}
child:selected *,
row:selected * {
  color: @m_base;
}

.item-text { font-family: "$FONT"; font-size: 14px; color: @m_text; }
.item-subtext { font-family: "$FONT"; font-size: 12px; color: alpha(@m_muted, 0.9); }

scrollbar { opacity: 0; }

.item-quick-activation,
.keybinds,
.global-keybinds,
.item-keybinds { opacity: 0; font-size: 0px; min-width: 0px; min-height: 0px; margin: 0px; padding: 0px; }
.normal-icons { -gtk-icon-size: 16px; }
.item-icon { margin-right: 2px; }
.large-icons { -gtk-icon-size: 32px; }
EOF
echo "SYNC-OK radius=${R}px font=$FONT base=$BASE accent=$ACC"
