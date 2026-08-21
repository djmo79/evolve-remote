#!/usr/bin/env python3
"""Build the Evolve IT Remote app icon from the company logo's mark.

The logo is a wide wordmark plus a distinct blue mark (cascading cards + power
button). Only the mark makes sense square, so we isolate it by colour (the
wordmark is black, the mark is blue), trim to it, and set it on a brand-cream
rounded square at the sizes macOS (.icns) and Windows (.ico) want.
"""
#
# Usage: python3 res/evolve/make_icon.py path/to/logo.png [out_dir]
# The logo is the Evolve IT wordmark+mark PNG from the RMM
# (apps/portal/public/logo.png). Writes AppIcon.icns and app_icon.ico into
# out_dir (default ./icon-out); copy those over flutter/macos/Runner/AppIcon.icns
# and flutter/windows/runner/resources/app_icon.ico. Needs Pillow + iconutil.
import os
import subprocess
import sys
from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else "logo.png"
OUT = sys.argv[2] if len(sys.argv) > 2 else "icon-out"
CREAM = (244, 246, 249, 255)  # #F4F6F9, the brand ground

os.makedirs(OUT, exist_ok=True)
img = Image.open(SRC).convert("RGBA")
w, h = img.size
px = img.load()

# Bounding box of the blue mark: pixels that are clearly blue (b dominant) and
# opaque. This excludes the black wordmark (r≈g≈b, all low) and transparency.
minx, miny, maxx, maxy = w, h, 0, 0
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a > 40 and b > 90 and b >= r + 20 and b >= g + 10:
            minx, miny = min(minx, x), min(miny, y)
            maxx, maxy = max(maxx, x), max(maxy, y)
if maxx <= minx or maxy <= miny:
    raise SystemExit("could not locate the blue mark")
print(f"mark bbox: ({minx},{miny})-({maxx},{maxy}) in {w}x{h}")

mark = img.crop((minx, miny, maxx + 1, maxy + 1))
mark = mark.crop(mark.getbbox())  # tighten to opaque pixels

# Compose a 1024 master: cream rounded square, mark centred at ~72% of the box.
S = 1024
canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bg = Image.new("RGBA", (S, S), CREAM)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=255)
canvas.paste(bg, (0, 0), mask)

target = int(S * 0.72)
mw, mh = mark.size
scale = min(target / mw, target / mh)
mark = mark.resize((max(1, int(mw * scale)), max(1, int(mh * scale))), Image.LANCZOS)
canvas.alpha_composite(mark, ((S - mark.width) // 2, (S - mark.height) // 2))

master = os.path.join(OUT, "icon_1024.png")
canvas.save(master)
print("master:", master)

# --- macOS .icns via iconutil ---
iconset = os.path.join(OUT, "AppIcon.iconset")
os.makedirs(iconset, exist_ok=True)
for base in (16, 32, 128, 256, 512):
    for scale, suffix in ((1, ""), (2, "@2x")):
        s = base * scale
        canvas.resize((s, s), Image.LANCZOS).save(
            os.path.join(iconset, f"icon_{base}x{base}{suffix}.png")
        )
icns = os.path.join(OUT, "AppIcon.icns")
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
print("icns:", icns)

# --- Windows .ico (multi-size embedded) ---
ico = os.path.join(OUT, "app_icon.ico")
canvas.save(ico, sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
print("ico:", ico)
