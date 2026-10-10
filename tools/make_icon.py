#!/usr/bin/env python3
"""Buat logo dan ikon aplikasi CERDAS (gambar sendiri, tanpa aset luar).

Tanda: burung hantu geometris, lambang cerdas sekaligus pengawas yang selalu waspada. Kedua matanya digambar sebagai
kotak deteksi dengan sudut bidik, seperti kotak keluaran YOLO di aplikasi, dan paruhnya jingga seperti warna
peringatan saat peserta menoleh. Warna sama dengan lib/theme/app_theme.dart.
Pakai (dari akar repo): python3 tools/make_icon.py
"""

import json
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

    # kepala bulat dengan dua jumbai bulu yang miring keluar
    head = [
        p(0.21, 0.36), p(0.25, 0.17), p(0.37, 0.29), p(0.63, 0.29), p(0.75, 0.17), p(0.79, 0.36),
        p(0.81, 0.56), p(0.76, 0.73), p(0.64, 0.83), p(0.50, 0.87), p(0.36, 0.83), p(0.24, 0.73), p(0.19, 0.56),
    ]
    d.polygon(head, fill=CHALK)
    # piringan wajah: dua lingkaran sedikit lebih gelap di belakang mata
    disc = (217, 211, 198)
    for cx in (0.375, 0.625):
        d.ellipse((p(cx - 0.155, 0.47 - 0.155), p(cx + 0.155, 0.47 + 0.155)), fill=disc)
    # bulu dada: tiga lekuk kecil
    fw = max(1, round(0.018 * s))
    for (x, y) in ((0.42, 0.76), (0.58, 0.76), (0.50, 0.80)):
        d.line([p(x - 0.035, y - 0.02), p(x, y + 0.012), p(x + 0.035, y - 0.02)], fill=disc, width=fw, joint="curve")
    # mata: kotak deteksi dengan sudut bidik hijau, pupil gelap di tengah
    w = max(1, round(0.026 * s))
    for cx in (0.375, 0.625):
        cy, half, arm = 0.47, 0.105, 0.045
        x0, y0, x1, y1 = cx - half, cy - half, cx + half, cy + half
        d.rounded_rectangle((p(x0, y0), p(x1, y1)), radius=0.03 * s, fill=GRAPHITE)
        for (ax, ay, sx, sy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
            ix, iy = ax + sx * 0.022, ay + sy * 0.022
            d.line([p(ix, iy + sy * arm), p(ix, iy), p(ix + sx * arm, iy)], fill=SAFE, width=w)
        r = 0.035
        d.ellipse((p(cx - r, cy - r), p(cx + r, cy + r)), fill=SAFE)
        hl = 0.012
        d.ellipse((p(cx + 0.008 - hl, cy - 0.012 - hl), p(cx + 0.008 + hl, cy - 0.012 + hl)), fill=CHALK)
    # paruh jingga
    d.polygon([p(0.47, 0.60), p(0.53, 0.60), p(0.50, 0.68)], fill=TURN)


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
