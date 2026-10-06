#!/usr/bin/env python3
"""Buat logo dan ikon aplikasi Deteksi Mencontek (gambar sendiri, tanpa aset luar).

Tanda: bingkai sudut (viewfinder) berwarna kapur dengan mata di tengah,
iris hijau "fokus". Warna sama dengan lib/theme/app_theme.dart.
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
SS = 4


def draw_mark(img, s, ox=0.0, oy=0.0):
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (ox + x * s, oy + y * s)

    w = max(1, round(0.055 * s))
    # Bingkai sudut.
    a, b, L = 0.18, 0.82, 0.17
    for (cx, cy, sx, sy) in [(a, a, 1, 1), (b, a, -1, 1), (a, b, 1, -1), (b, b, -1, -1)]:
        d.line([p(cx, cy + sy * L), p(cx, cy), p(cx + sx * L, cy)], fill=CHALK, width=w, joint="curve")
        r = w / 2
        for (x, y) in [(cx, cy + sy * L), (cx + sx * L, cy), (cx, cy)]:
            px, py = p(x, y)
            d.ellipse((px - r, py - r, px + r, py + r), fill=CHALK)
    # Mata (dua busur membentuk almond).
    pts_top, pts_bot = [], []
    for i in range(41):
        t = i / 40
        x = 0.28 + 0.44 * t
        h = 0.15 * math.sin(math.pi * t)
        pts_top.append(p(x, 0.5 - h))
        pts_bot.append(p(x, 0.5 + h))
    d.polygon(pts_top + pts_bot[::-1], fill=CHALK)
    # Iris dan pupil.
    for (r, col) in [(0.105, SAFE), (0.045, GRAPHITE)]:
        d.ellipse((p(0.5 - r, 0.5 - r), p(0.5 + r, 0.5 + r)), fill=col)
    hl = 0.018
    d.ellipse((p(0.535 - hl, 0.465 - hl), p(0.535 + hl, 0.465 + hl)), fill=CHALK)


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
    render(256, rounded=False).save(out / "logo.png")


if __name__ == "__main__":
    android()
    ios()
    web()
    brand()
    print("Ikon dibuat.")
