#!/usr/bin/env python3
"""Extrahiert die animierte Flagge (animierter Layer mit Keyframes) aus einer
.kra-Datei als PNG-Sequenz. Aufruf:
    python3 gen_flag.py /pfad/flag.kra ../../assets/flagge
Alle Frames werden auf eine gemeinsame Bounding-Box zugeschnitten (gleiche
Größe + Ausrichtung), damit die Animation in Godot nicht "wackelt".
"""
import sys, zipfile, re, os
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

# animierten Layer + seine keyframes-Datei finden
anim = re.search(r'<layer\b[^>]*keyframes="([^"]*)"[^>]*filename="([^"]*)"', maindoc)
if not anim:
    anim = re.search(r'<layer\b[^>]*filename="([^"]*)"[^>]*keyframes="([^"]*)"', maindoc)
    kf_file, base = anim.group(2), anim.group(1)
else:
    kf_file, base = anim.group(1), anim.group(2)
print(f"Canvas {W}x{H}, animierter Layer '{base}', keyframes='{kf_file}'")

kf_xml = z.read(f"{docname}/layers/{kf_file}").decode("utf-8", "replace")
# (time, framefile) sammeln und nach Zeit sortieren
frames = []
for m in re.finditer(r'<keyframe[^>]*frame="([^"]*)"[^>]*time="(\d+)"', kf_xml):
    frames.append((int(m.group(2)), m.group(1)))
frames.sort()
print(f"{len(frames)} Frames (Zeit {frames[0][0]}..{frames[-1][0]})")


def load_frame(framefile):
    raw = z.read(f"{docname}/layers/{framefile}")
    tw, th, tiles = KE.parse_layer(raw)
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    for (x, y, rgba) in tiles:
        cx0, cy0 = max(0, x), max(0, y)
        cx1, cy1 = min(W, x + tw), min(H, y + th)
        if cx0 >= cx1 or cy0 >= cy1:
            continue
        canvas[cy0:cy1, cx0:cx1] = rgba[cy0 - y:cy1 - y, cx0 - x:cx1 - x]
    return Image.fromarray(canvas, "RGBA")


# 1) alle Frames laden, gemeinsame Bounding-Box bestimmen
imgs = []
union = None
for t, ff in frames:
    im = load_frame(ff)
    imgs.append(im)
    bb = im.getbbox()
    if bb:
        union = bb if union is None else (
            min(union[0], bb[0]), min(union[1], bb[1]),
            max(union[2], bb[2]), max(union[3], bb[3]))
print(f"gemeinsame BBox = {union}  -> Größe {union[2]-union[0]}x{union[3]-union[1]}")

# 2) auf gemeinsame BBox zuschneiden + speichern
for i, im in enumerate(imgs):
    im.crop(union).save(os.path.join(OUTDIR, "frame_%02d.png" % i))
print(f"{len(imgs)} Frames -> {OUTDIR}/frame_00.png .. frame_%02d.png" % (len(imgs) - 1))

# kleine Vorschau-Montage (jeden 4. Frame) zum Prüfen
step = max(1, len(imgs) // 9)
cell = 90
cols = len(range(0, len(imgs), step))
sheet = Image.new("RGBA", (cols * cell, cell), (200, 200, 200, 255))
for c, i in enumerate(range(0, len(imgs), step)):
    th = imgs[i].crop(union).copy()
    th.thumbnail((cell - 6, cell - 6))
    sheet.alpha_composite(th, (c * cell + 3, 3))
sheet.save(os.path.join(OUTDIR, "_preview_strip.png"))
print("Vorschau: _preview_strip.png")
