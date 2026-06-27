#!/usr/bin/env python3
"""Zerlegt die Krita-Figur in saubere, farbige Einzelteile (fuer Ragdoll).
- setzt die ganze Figur farbig zusammen (Fuellungen + Umrisse)
- schneidet jeden Koerperteil ueber die gefuellte Silhouette seines Umrisses aus
- speichert eng zugeschnittene PNGs + manifest.json (bbox/center in Canvas-Koord.)
"""
import sys, zipfile, re, os, json
from collections import deque
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kra_extract as KE

KRA = sys.argv[1]
OUTDIR = sys.argv[2]
os.makedirs(OUTDIR, exist_ok=True)

z = zipfile.ZipFile(KRA)
maindoc = z.read("maindoc.xml").decode("utf-8", "replace")
W = int(re.search(r'<IMAGE[^>]*width="(\d+)"', maindoc).group(1))
H = int(re.search(r'<IMAGE[^>]*height="(\d+)"', maindoc).group(1))
docname = re.search(r'<IMAGE[^>]*name="([^"]*)"', maindoc).group(1)

# Layer in Dokumentreihenfolge (erste = oberste). filename + sichtbar.
order = []
for m in re.finditer(r'<layer\b[^>]*>', maindoc):
    tag = m.group(0)
    nm = re.search(r'(?:^|\s)name="([^"]*)"', tag).group(1)
    fn = re.search(r'(?:^|\s)filename="([^"]*)"', tag).group(1)
    vis = re.search(r'visible="(\d+)"', tag).group(1) == "1"
    order.append((nm, fn, vis))


def load(fn):
    raw = z.read(f"{docname}/layers/{fn}")
    tw, th, tiles = KE.parse_layer(raw)
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    for (x, y, rgba) in tiles:
        cx0, cy0 = max(0, x), max(0, y)
        cx1, cy1 = min(W, x + tw), min(H, y + th)
        if cx0 >= cx1 or cy0 >= cy1:
            continue
        canvas[cy0:cy1, cx0:cx1] = rgba[cy0 - y:cy1 - y, cx0 - x:cx1 - x]
    return canvas


# 1) Ganze Figur farbig zusammensetzen (nur sichtbare Layer, von unten nach oben)
full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cache = {}
for nm, fn, vis in reversed(order):
    if not vis:
        continue
    arr = load(fn)
    cache[nm] = arr
    full.alpha_composite(Image.fromarray(arr, "RGBA"))
full_np = np.array(full)


def dilate(mask, it=1):
    m = mask.copy()
    for _ in range(it):
        d = m.copy()
        d[1:, :] |= m[:-1, :]; d[:-1, :] |= m[1:, :]
        d[:, 1:] |= m[:, :-1]; d[:, :-1] |= m[:, 1:]
        m = d
    return m


def silhouette(line):
    """line: bool-Maske der Umrisslinien (volle Canvasgroesse).
    Liefert gefuellte Silhouette (Innenflaeche + Linien)."""
    ys, xs = np.where(line)
    if len(xs) == 0:
        return line
    pad = 6
    x0, x1 = max(0, xs.min() - pad), min(W, xs.max() + pad + 1)
    y0, y1 = max(0, ys.min() - pad), min(H, ys.max() + pad + 1)
    sub = dilate(line[y0:y1, x0:x1], 2)   # kleine Luecken im Strich schliessen
    h, w = sub.shape
    outside = np.zeros((h, w), dtype=bool)
    dq = deque()
    for xx in range(w):
        for yy in (0, h - 1):
            if not sub[yy, xx] and not outside[yy, xx]:
                outside[yy, xx] = True; dq.append((yy, xx))
    for yy in range(h):
        for xx in (0, w - 1):
            if not sub[yy, xx] and not outside[yy, xx]:
                outside[yy, xx] = True; dq.append((yy, xx))
    while dq:
        yy, xx = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = yy + dy, xx + dx
            if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx] and not sub[ny, nx]:
                outside[ny, nx] = True; dq.append((ny, nx))
    sil_sub = ~outside            # Innen + Linien
    sil = np.zeros((H, W), dtype=bool)
    sil[y0:y1, x0:x1] = sil_sub
    return sil


manifest = {"canvas": [W, H], "parts": {}}
reassemble = Image.new("RGBA", (W, H), (255, 255, 255, 255))

for layername, outname in KE.WANTED.items():
    outline = cache[layername]
    line = outline[:, :, 3] > 30
    sil = silhouette(line)
    # Falls Fuellung durch Luecke ausgelaufen waere (Silhouette ~ nur Linien):
    line_area = int(line.sum()); sil_area = int(sil.sum())
    leaked = sil_area < line_area * 1.6
    # farbige Pixel aus der Gesamtfigur, maskiert mit Silhouette
    part = np.zeros((H, W, 4), dtype=np.uint8)
    part[sil] = full_np[sil]
    # wo die Silhouette deckt, aber die Gesamtfigur dort transparent ist
    # (z.B. weil ein anderes Teil drueberlag), eigenen Umriss einsetzen
    need = sil & (part[:, :, 3] < 10) & (outline[:, :, 3] > 0)
    part[need] = outline[need]
    img = Image.fromarray(part, "RGBA")
    bbox = img.getbbox()
    crop = img.crop(bbox)
    crop.save(os.path.join(OUTDIR, outname + ".png"))
    cx = (bbox[0] + bbox[2]) / 2.0
    cy = (bbox[1] + bbox[3]) / 2.0
    manifest["parts"][outname] = {
        "bbox": list(bbox), "center": [cx, cy],
        "size": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "leaked": leaked,
    }
    reassemble.alpha_composite(img)
    flag = "  <-- LECK?" if leaked else ""
    print(f"  {outname:22s} bbox={bbox} center=({cx:.0f},{cy:.0f}){flag}")

json.dump(manifest, open(os.path.join(OUTDIR, "manifest.json"), "w"), indent=2)
reassemble.crop((230, 160, 800, 850)).save(os.path.join(OUTDIR, "_reassembled.png"))
print("manifest + _reassembled.png geschrieben")
