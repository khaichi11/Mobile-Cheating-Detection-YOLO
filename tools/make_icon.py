#!/usr/bin/env python3
"""Buat logo dan ikon aplikasi CERDAS (gambar sendiri, tanpa aset luar).

Tanda: ilustrasi seorang peserta ujian yang menghadap depan, dibingkai empat sudut bidik hijau "fokus", di atas latar
kertas. Gambarnya sama dengan wajah pada pembuka aplikasi (lib/widgets/proctor_intro.dart): rambut pendek dengan
poni menyamping, dua mata, dan kemeja berkerah. Warna sama dengan lib/theme/app_theme.dart.
Pakai (dari akar repo): python3 tools/make_icon.py
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PAPER = (244, 242, 235)
SAFE = (35, 128, 79)
SKIN = (240, 194, 154)
SKIN_SHADE = (226, 169, 126)
EAR = (230, 178, 134)
HAIR = (42, 36, 32)
SHIRT = (52, 85, 139)
INK = (30, 30, 30)
SS = 4


def _cubic(p0, p1, p2, p3, n=24):
    return [
        (
            (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0],
            (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1],
        )
        for t in (i / n for i in range(n + 1))
    ]


def _quad(p0, p1, p2, n=16):
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1])
        for t in (i / n for i in range(n + 1))
    ]


def _round(d, a, b, r, fill):
    """Persegi membulat yang tetap aman untuk ikon sangat kecil (jari-jari dibatasi ukuran kotak)."""
    r = min(r, (b[0] - a[0]) / 2 - 1, (b[1] - a[1]) / 2 - 1)
    if r < 1:
        d.ellipse((a, b), fill=fill)
    else:
        d.rounded_rectangle((a, b), radius=r, fill=fill)


def draw_mark(img, s, ox=0.0, oy=0.0):
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (ox + x * s, oy + y * s)

    # sudut bidik
    w = max(1, round(0.05 * s))
    a, b, L = 0.15, 0.85, 0.15
    for (cx, cy, sx, sy) in [(a, a, 1, 1), (b, a, -1, 1), (a, b, 1, -1), (b, b, -1, -1)]:
        d.line([p(cx, cy + sy * L), p(cx, cy), p(cx + sx * L, cy)], fill=SAFE, width=w, joint="curve")
        r = w / 2
        for (x, y) in [(cx, cy + sy * L), (cx + sx * L, cy), (cx, cy)]:
            px, py = p(x, y)
            d.ellipse((px - r, py - r, px + r, py + r), fill=SAFE)

    # peserta: satuan sama dengan gambar di pembuka, dipusatkan dan diperkecil
    u, cx0, cy0 = 0.0031, 0.5, 0.47

    def q(x, y):
        return p(cx0 + x * u, cy0 + y * u)

    shirt = [q(-78, 104), q(-74, 74)] + [q(*pt) for pt in _quad((-70, 56), (-70, 56), (-44, 50))] + [q(44, 50)]
    shirt += [q(*pt) for pt in _quad((44, 50), (70, 56), (74, 74))] + [q(78, 104)]
    d.polygon(shirt, fill=SHIRT)
    d.polygon([q(-20, 50), q(0, 72), q(20, 50)], fill=PAPER)
    _round(d, q(-13, 30), q(13, 56), 6 * u * s, SKIN_SHADE)
    for side in (-1, 1):
        ex = side * 44
        d.ellipse((q(ex - 7, -8), q(ex + 7, 12)), fill=EAR)
    _round(d, q(-44, -52), q(44, 48), 42 * u * s, SKIN)
    hair = (
        _cubic((-46, 4), (-52, -46), (-22, -66), (6, -64))
        + _cubic((6, -64), (40, -62), (54, -38), (46, 2))
        + _cubic((46, 2), (42, -14), (34, -24), (22, -28))
        + _cubic((22, -28), (4, -16), (-22, -18), (-40, -14))
        + _cubic((-40, -14), (-42, -6), (-44, 0), (-46, 4))
    )
    d.polygon([q(*pt) for pt in hair], fill=HAIR)
    for side in (-1, 1):
        ex = side * 17
        d.ellipse((q(ex - 4.5, -2), q(ex + 4.5, 10)), fill=INK)
        d.ellipse((q(ex + 0.2, -0.8), q(ex + 3.4, 2.4)), fill=(255, 255, 255))


def render(size, *, rounded, background=True, scale=1.0):
    big = size * SS
    if background:
        img = Image.new("RGBA", (big, big), PAPER + (255,))
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
        '    <color name="ic_launcher_background">#F4F2EB</color>\n'
        '    <color name="launch_background">#F4F2EB</color>\n'
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
