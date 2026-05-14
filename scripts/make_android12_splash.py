#!/usr/bin/env python3
"""
Génère assets/splash/joyeux_square.png pour flutter_native_splash Android 12.

Android 12 affiche l'icône de splash dans un cercle de 240 dp.
Zone sûre (rien n'est coupé par le masque circulaire) = 160/240 = 66.7 % du côté.
On vise 60 % pour une marge confortable.

Usage :
    cd dony_app/
    python3 scripts/make_android12_splash.py
"""

from pathlib import Path
from PIL import Image

SRC = Path("assets/mascotte/joyeux.png")
DST_DIR = Path("assets/splash")
DST = DST_DIR / "joyeux_square.png"

CANVAS = 1024      # px — côté du canvas carré
FILL = 0.60        # la mascotte occupe 60 % du côté (confortablement dans la zone sûre)

DST_DIR.mkdir(parents=True, exist_ok=True)

mascotte = Image.open(SRC).convert("RGBA")
src_w, src_h = mascotte.size
print(f"Source : {SRC}  ({src_w}×{src_h} px)")

max_side = int(CANVAS * FILL)
ratio = min(max_side / src_w, max_side / src_h)
new_w, new_h = int(src_w * ratio), int(src_h * ratio)
mascotte = mascotte.resize((new_w, new_h), Image.LANCZOS)
print(f"Redimensionnée : {new_w}×{new_h} px  (ratio {ratio:.2f})")

canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
x = (CANVAS - new_w) // 2
y = (CANVAS - new_h) // 2
canvas.paste(mascotte, (x, y), mascotte)

canvas.save(DST, "PNG")
print(f"✅ Enregistrée : {DST}  ({CANVAS}×{CANVAS} px)")
print()
print("Ajoutez dans pubspec.yaml → flutter_native_splash → android_12 :")
print(f"    image: {DST}")
