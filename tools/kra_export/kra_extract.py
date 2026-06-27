#!/usr/bin/env python3
"""Extrahiert einzelne Paint-Layer aus einer .kra-Datei als voll-canvas PNGs.
Dekodiert das Krita-Tileformat (VERSION 2, LZF) ohne Krita."""
import sys, zipfile, re, os
import numpy as np
from PIL import Image

KRA = sys.argv[1] if len(sys.argv) > 1 else None
OUTDIR = sys.argv[2] if len(sys.argv) > 2 else None

# Welche Layer interessieren uns (Name -> Ausgabedateiname, ohne .png)
WANTED = {
    "Kopf": "kopf",
    "body": "body",
    "oberarm-links": "oberarm_links",
    "unterarm-links": "unterarm_links",
    "hand-links": "hand_links",
    "oberschenkel-links": "oberschenkel_links",
    "unterschenkel-links": "unterschenkel_links",
    "Fuß-links": "fuss_links",
    "oberarm-rechts": "oberarm_rechts",
    "unterarm-rechts": "unterarm_rechts",
    "Hand-rechts": "hand_rechts",
    "oberschenkel-rechts": "oberschenkel_rechts",
    "unterschenkel-rechts": "unterschenkel_rechts",
    "fruß-rechts": "fuss_rechts",
}


def lzf_decompress(data, expected):
    """Standard liblzf decompress (wie Krita es schreibt)."""
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        ctrl = data[i]; i += 1
        if ctrl < 32:                       # literal run
            length = ctrl + 1
            out += data[i:i+length]; i += length
        else:                               # back reference
            length = ctrl >> 5
            if length == 7:
                length += data[i]; i += 1
            ref = len(out) - ((ctrl & 0x1f) << 8) - data[i] - 1; i += 1
            for _ in range(length + 2):
                out.append(out[ref]); ref += 1
    if len(out) != expected:
        # nicht fatal, aber melden
        sys.stderr.write(f"  WARN: dekomprimiert {len(out)} != {expected}\n")
    return bytes(out)


def parse_layer(raw):
    """Parst eine Krita-Layerdatei -> Liste von (x, y, 64x64x4 BGRA ndarray)."""
    # Header: bis "DATA n\n"
    header_end = raw.index(b"DATA ")
    line_end = raw.index(b"\n", header_end)
    hdr = raw[:line_end].decode("ascii", "replace")
    tw = int(re.search(r"TILEWIDTH (\d+)", hdr).group(1))
    th = int(re.search(r"TILEHEIGHT (\d+)", hdr).group(1))
    ps = int(re.search(r"PIXELSIZE (\d+)", hdr).group(1))
    ntiles = int(re.search(r"DATA (\d+)", hdr).group(1))
    pos = line_end + 1
    tilebytes = tw * th * ps
    tiles = []
    for _ in range(ntiles):
        meta_end = raw.index(b"\n", pos)
        meta = raw[pos:meta_end].decode("ascii")
        pos = meta_end + 1
        x_str, y_str, comp, size_str = meta.split(",")
        x, y, size = int(x_str), int(y_str), int(size_str)
        block = raw[pos:pos+size]; pos += size
        flag = block[0]                     # 1 = LZF komprimiert, 0 = roh
        payload = block[1:]
        data = lzf_decompress(payload, tilebytes) if flag == 1 else payload
        # Krita speichert die Tile-Daten PLANAR: erst die ganze B-Ebene,
        # dann G, dann R, dann A (jeweils th*tw Bytes).
        planes = np.frombuffer(data, dtype=np.uint8)[:tilebytes].reshape(ps, th, tw)
        # BGRA-Ebenen -> RGBA-Bild (h, w, 4)
        rgba = np.stack([planes[2], planes[1], planes[0], planes[3]], axis=-1)
        tiles.append((x, y, rgba))
    return tw, th, tiles


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    z = zipfile.ZipFile(KRA)
    maindoc = z.read("maindoc.xml").decode("utf-8", "replace")
    W = int(re.search(r'<IMAGE[^>]*width="(\d+)"', maindoc).group(1))
    H = int(re.search(r'<IMAGE[^>]*height="(\d+)"', maindoc).group(1))
    docname = re.search(r'<IMAGE[^>]*name="([^"]*)"', maindoc).group(1)
    print(f"Canvas {W}x{H}, doc='{docname}'")

    # name -> filename
    name2file = {}
    for m in re.finditer(r'<layer\b[^>]*>', maindoc):
        tag = m.group(0)
        nm = re.search(r'(?:^|\s)name="([^"]*)"', tag)
        fn = re.search(r'(?:^|\s)filename="([^"]*)"', tag)
        if nm and fn:
            name2file[nm.group(1)] = fn.group(1)

    for layername, outname in WANTED.items():
        fn = name2file.get(layername)
        if not fn:
            print(f"  !! Layer '{layername}' nicht gefunden"); continue
        raw = z.read(f"{docname}/layers/{fn}")
        tw, th, tiles = parse_layer(raw)
        canvas = np.zeros((H, W, 4), dtype=np.uint8)   # RGBA
        for (x, y, rgba) in tiles:
            x0, y0 = x, y
            x1, y1 = x + tw, y + th
            # auf Canvas clippen
            cx0, cy0 = max(0, x0), max(0, y0)
            cx1, cy1 = min(W, x1), min(H, y1)
            if cx0 >= cx1 or cy0 >= cy1:
                continue
            sx0, sy0 = cx0 - x0, cy0 - y0
            canvas[cy0:cy1, cx0:cx1, :] = rgba[sy0:sy0+(cy1-cy0), sx0:sx0+(cx1-cx0), :]
        img = Image.fromarray(canvas, "RGBA")
        # auf Inhalt zuschneiden? Nein - volle Canvas behalten fuer Ausrichtung.
        out = os.path.join(OUTDIR, outname + ".png")
        img.save(out)
        bbox = img.getbbox()
        print(f"  {layername:24s} -> {outname}.png  (Inhalt-BBox {bbox})")



if __name__ == "__main__":
    main()
