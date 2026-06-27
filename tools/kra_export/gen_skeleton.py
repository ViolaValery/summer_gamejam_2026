#!/usr/bin/env python3
"""Erzeugt aus den Einzelteilen + manifest.json:
  - figur_preview.png  (ganze Figur, zugeschnitten) fuer die Werkstatt-Vorschau
  - SKELETT-Daten als GDScript-Dict (Gelenkpunkte, Parent, Bildgroesse)
Koordinaten sind in Canvas-Pixeln (1024er Raum), wie im Manifest.
"""
import json, os
from PIL import Image

SRC = "/home/lukas/Documents/funProjects/summer_gamejam_2026/assets/figur"
man = json.load(open(os.path.join(SRC, "manifest.json")))
parts = man["parts"]
W, H = man["canvas"]

# Verbindungen (Gelenke): (kind_a, kind_b). Pin sitzt mittig zwischen den Zentren.
JOINTS = [
    ("body", "kopf"),
    ("body", "oberarm_links"),
    ("oberarm_links", "unterarm_links"),
    ("unterarm_links", "hand_links"),
    ("body", "oberarm_rechts"),
    ("oberarm_rechts", "unterarm_rechts"),
    ("unterarm_rechts", "hand_rechts"),
    ("body", "oberschenkel_links"),
    ("oberschenkel_links", "unterschenkel_links"),
    ("unterschenkel_links", "fuss_links"),
    ("body", "oberschenkel_rechts"),
    ("oberschenkel_rechts", "unterschenkel_rechts"),
    ("unterschenkel_rechts", "fuss_rechts"),
]

# 1) Vorschaubild: alle Teile auf voller Canvas zusammensetzen, dann zuschneiden
full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
order = ["oberschenkel_links","unterschenkel_links","fuss_links",
         "oberarm_links","unterarm_links","hand_links",
         "oberschenkel_rechts","unterschenkel_rechts","fuss_rechts",
         "oberarm_rechts","unterarm_rechts","hand_rechts","body","kopf"]
for k in order:
    im = Image.open(os.path.join(SRC, k + ".png"))
    bb = parts[k]["bbox"]
    full.alpha_composite(im, (bb[0], bb[1]))
fbb = full.getbbox()
preview = full.crop(fbb)
preview.save(os.path.join(SRC, "figur_preview.png"))
print(f"figur_preview.png  size={preview.size}  fig-bbox={fbb}")

# Hand-rechts Zentrum relativ zur Vorschau-Ecke (fuer Sprite-Offset)
hc = parts["hand_rechts"]["center"]
hand_in_preview = (hc[0] - fbb[0], hc[1] - fbb[1])
print(f"hand_rechts center in preview = {hand_in_preview}")

# 2) Skelett als GDScript-Dict ausgeben
def mid(a, b):
    ca, cb = parts[a]["center"], parts[b]["center"]
    return [(ca[0]+cb[0])/2.0, (ca[1]+cb[1])/2.0]

print("\n# ---- GDScript: in figur.gd einsetzen ----")
print("const FIG_BBOX := Vector2(%g, %g)  # linke obere Ecke der Figur in Canvas" % (fbb[0], fbb[1]))
print("const PREVIEW_SIZE := Vector2(%g, %g)" % preview.size)
print("const HAND_IN_PREVIEW := Vector2(%g, %g)" % hand_in_preview)
print("\n# Teil -> { center (Canvas), size }")
print("const PARTS := {")
for k in order:
    c = parts[k]["center"]; s = parts[k]["size"]
    print('\t"%s": {"center": Vector2(%g, %g), "size": Vector2(%g, %g)},' % (k, c[0], c[1], s[0], s[1]))
print("}")
print("\n# Gelenke: [teil_a, teil_b, pin_pos (Canvas)]")
print("const BONES := [")
for a, b in JOINTS:
    m = mid(a, b)
    print('\t["%s", "%s", Vector2(%g, %g)],' % (a, b, m[0], m[1]))
print("]")
