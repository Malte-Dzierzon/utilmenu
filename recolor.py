# Liest utilmenu-apps.list, löst Icons auf, mappt auf Zielfarbe (Luminanz bleibt).
import os, subprocess, sys
from PIL import Image
COLOR, OUTDIR = (sys.argv[1:3] + ['#ffb4ab', os.path.expanduser('~/.cache/utilmenu-icons')])[:2]
tr, tg, tb = int(COLOR[1:3],16), int(COLOR[3:5],16), int(COLOR[5:7],16)
def resolve(icon):
    if not icon: return None
    if os.path.isfile(icon): return icon
    for base in [os.path.expanduser("~/.local/share/icons"),
                 "/run/current-system/sw/share/icons",
                 os.path.expanduser("~/.nix-profile/share/icons"),
                 "/usr/share/icons"]:
        for ext in (".png", ".svg"):
            for pat in [f"{base}/hicolor/48x48/apps/{icon}{ext}",
                        f"{base}/hicolor/scalable/apps/{icon}{ext}",
                        f"{base}/{icon}{ext}"]:
                if os.path.isfile(pat): return pat
    return None
def raster(path):
    if path.endswith(".svg"):
        import tempfile
        tmp = tempfile.mktemp(suffix=".png")
        subprocess.run(["rsvg-convert", "-w", "48", "-h", "48", "-o", tmp, path],
                       check=True, capture_output=True)
        return tmp, True
    return path, False
n = 0
for line in open(os.path.expanduser("~/.cache/utilmenu-apps.list")):
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 3: continue
    name = parts[1].strip()
    icon = parts[3].strip() if len(parts) > 3 else ""
    src = resolve(icon)
    if not src or not name: continue
    try:
        png, is_tmp = raster(src)
        img = Image.open(png).convert("RGBA")
        px = img.load()
        w, h = img.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a < 8: continue
                # Noctalia-Prinzip: Alpha = Form, Farbe = deckend app_icon_color
                px[x, y] = (tr, tg, tb, a)
        safe = "".join(c if c.isalnum() else "_" for c in name)[:40]
        img.save(os.path.join(OUTDIR, safe + ".png"))
        n += 1
        if is_tmp: os.unlink(png)
    except Exception: continue
print(f"RECOLORED: {n}")
