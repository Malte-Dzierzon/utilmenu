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
                 "/run/current-system/sw/share/pixmaps",
                 os.path.expanduser("~/.nix-profile/share/icons"),
                 os.path.expanduser("~/.nix-profile/share/pixmaps"),
                 "/usr/share/icons",
                 "/usr/share/pixmaps"]:
        for ext in (".png", ".svg"):
            import glob
            for pat in [f"{base}/hicolor/scalable/apps/{icon}{ext}",
                        f"{base}/hicolor/48x48/apps/{icon}{ext}",
                        f"{base}/{icon}{ext}"]:
                if os.path.isfile(pat): return pat
            import glob
            hits = glob.glob(f"{base}/hicolor/scalable/apps/{icon}{ext}")
            hits += glob.glob(f"{base}/hicolor/*/apps/{icon}{ext}")
            hits += glob.glob(f"{base}/**/{icon}{ext}", recursive=True)
            if hits: return sorted(hits)[0]
    return None
def raster(path):
    if path.endswith(".svg"):
        import tempfile
        tmp = tempfile.mktemp(suffix=".png")
        subprocess.run(["rsvg-convert", "-w", "48", "-h", "48", "-o", tmp, path],
                       check=True, capture_output=True)
        return tmp, True
    return path, False
import hashlib
outhash = os.path.join(OUTDIR, ".srchash")
srchash = hashlib.sha256((COLOR + open(os.path.expanduser("~/.cache/utilmenu-apps.list"), "rb").read().decode(errors="replace")).encode()).hexdigest()
if os.path.isfile(outhash) and open(outhash).read().strip() == srchash:
    print("RECOLOR-SKIP: unverändert")
    sys.exit(0)
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
        w, h = img.size
        # Bimodal-Test: zwei Helligkeits-Cluster (dunkler Grund + helle Form)?
        # Dann helle Flächen als Hintergrund verwerfen, dunkle Form einfärben.
        import statistics
        lums = []
        for yy in range(0, h, 2):
            for xx in range(0, w, 2):
                r, g, b, a = img.getpixel((xx, yy))
                if a > 128: lums.append(0.299*r + 0.587*g + 0.114*b)
        bimodal = False
        if lums and statistics.pstdev(lums) > 50:
            dark = sum(1 for v in lums if v < 100) / len(lums)
            light = sum(1 for v in lums if v > 150) / len(lums)
            bimodal = dark > 0.25 and light > 0.12
        px = img.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a < 8: continue
                lum = (0.299*r + 0.587*g + 0.114*b) / 255.0
                if bimodal:
                    if lum > 0.55:
                        px[x, y] = (tr, tg, tb, a)  # helle Form -> deckend Farbe
                    else:
                        px[x, y] = (r, g, b, 0)  # dunkler Grund -> transparent
                else:
                    px[x, y] = (tr, tg, tb, int(a * lum))
        safe = "".join(c if c.isalnum() else "_" for c in name)[:40]
        img.save(os.path.join(OUTDIR, safe + ".png"))
        n += 1
        if is_tmp: os.unlink(png)
    except Exception: continue
open(outhash, "w").write(srchash)
print(f"RECOLORED: {n}")
