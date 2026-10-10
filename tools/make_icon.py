#!/usr/bin/env python3
"""Buat logo dan ikon aplikasi CERDAS (gambar sendiri, tanpa aset luar).

Tanda: monogram huruf C berupa busur tebal berwarna kapur. Titik hijau di tengahnya berarti peserta menghadap depan
(fokus), sedangkan tanda panah jingga di bukaan huruf C berarti kepala menoleh keluar, yaitu indikasi yang dicatat
aplikasi. Warna sama dengan lib/theme/app_theme.dart.
Pakai (dari akar repo): python3 tools/make_icon.py
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GRAPHITE = (15, 18, 22)
CHALK = (237, 234, 227)
SAFE = (79, 178, 134)
TURN = (224, 122, 60)
SS = 4


def draw_mark(img, s, ox=0.0, oy=0.0):
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (ox + x * s, oy + y * s)

    cx, cy, r, w = 0.48, 0.5, 0.29, 0.11
    # huruf C: busur tebal yang terbuka ke kanan, ujungnya membulat
    gap = 52  # derajat bukaan di kanan
    d.arc((p(cx - r, cy - r), p(cx + r, cy + r)), gap, 360 - gap, fill=CHALK, width=round(w * s))
    for ang in (gap, -gap):
        ex = cx + (r - w / 2) * math.cos(math.radians(ang))
        ey = cy + (r - w / 2) * math.sin(math.radians(ang))
        d.ellipse((p(ex - w / 2, ey - w / 2), p(ex + w / 2, ey + w / 2)), fill=CHALK)
    # titik fokus di tengah
    f = 0.085
    d.ellipse((p(cx - f, cy - f), p(cx + f, cy + f)), fill=SAFE)
    # panah toleh di bukaan huruf C
    t = 0.05
    d.line([p(0.72, cy - 0.085), p(0.81, cy), p(0.72, cy + 0.085)], fill=TURN, width=round(t * s), joint="curve")
    for x, y in ((0.72, cy - 0.085), (0.81, cy), (0.72, cy + 0.085)):
        d.ellipse((p(x - t / 2, y - t / 2), p(x + t / 2, y + t / 2)), fill=TURN)


def render(size, *, rounded, background=True, scale=1.0):
    big = size * SS
    if background:
        img = Image.new("RGBA", (big, big), GRAPHITE + (255,))
        if rounded:
            mask = Image.new("L", (big, big), 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=0.24 * big, fill=255)
            img.putalpha(mask)
    else:
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    side = big * scale
    offset = (big - side) / 2
    draw_mark(img, side, offset, offset)
    return img.resize((size, size), Image.LANCZOS)


def android():
    res = ROOT / "android/app/src/main/res"
    for name, factor in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        folder = res / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        render(round(48 * factor), rounded=True).save(folder / "ic_launcher.png")
        render(round(108 * factor), rounded=False, background=False, scale=0.66).save(
            folder / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n")
    (res / "values").mkdir(exist_ok=True)
    (res / "values/colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#0F1216</color>\n'
        '    <color name="launch_background">#0F1216</color>\n'
        "</resources>\n")
    nodpi = res / "drawable-nodpi"
    nodpi.mkdir(exist_ok=True)
    render(288, rounded=True).save(nodpi / "launch_logo.png")
    splash = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <item android:drawable="@color/launch_background" />\n'
              '    <item android:width="96dp" android:height="96dp" android:gravity="center">\n'
              '        <bitmap android:gravity="fill" android:src="@drawable/launch_logo" />\n'
              '    </item>\n'
              "</layer-list>\n")
    for folder in ("drawable", "drawable-v21"):
        (res / folder).mkdir(exist_ok=True)
        (res / folder / "launch_background.xml").write_text(splash)


def ios():
    folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text())
    for entry in contents["images"]:
        if not entry.get("filename"):
            continue
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        render(round(points * scale), rounded=False).convert("RGB").save(folder / entry["filename"])
    launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    if launch.exists():
        for name, size in (("LaunchImage.png", 96), ("LaunchImage@2x.png", 192), ("LaunchImage@3x.png", 288)):
            render(size, rounded=True).save(launch / name)


def web():
    icons = ROOT / "web/icons"
    if not icons.exists():
        return
    for name, size in (("Icon-192.png", 192), ("Icon-512.png", 512)):
        render(size, rounded=False).save(icons / name)
    for name, size in (("Icon-maskable-192.png", 192), ("Icon-maskable-512.png", 512)):
        img = render(size, rounded=False, scale=0.8)
        img.save(icons / name)
    render(32, rounded=True).save(ROOT / "web/favicon.png")


def brand():
    out = ROOT / "assets/brand"
    out.mkdir(parents=True, exist_ok=True)
    render(256, rounded=True).save(out / "logo.png")


if __name__ == "__main__":
    android()
    ios()
    web()
    brand()
    print("Ikon dibuat.")
