"""Bingkai ponsel generik untuk gambar dokumentasi.

Bingkai digambar sendiri dengan Pillow: badan membulat, lubang kamera, serta tombol daya dan volume. Bentuknya umum
dan tidak meniru merek mana pun, sehingga bebas dipakai bersama kode ini (Apache-2.0).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat

BODY = (44, 54, 74)  # biru batu tua, bukan hitam
RIM = (92, 104, 128)  # garis tepi tipis agar badan terlihat bervolume
SS = 3  # supersampling supaya tepi lengkung halus
BAR = 0.026  # tinggi bilah status terhadap tinggi layar
SHIFT = 0.045  # seberapa jauh jam dan ikon bilah status digeser ke tengah


def status_shift(w: int, h: int) -> tuple[int, int]:
    """Tinggi bilah status dan jarak geser ikonnya, dalam piksel."""
    return round(h * BAR), round(w * SHIFT)


def clear_corners(im: Image.Image) -> Image.Image:
    """Geser jam dan ikon bilah status sedikit ke tengah.

    Tangkapan layar emulator tidak punya sudut membulat, sehingga jam dan baterai menempel ke tepi dan terpotong
    lengkung bingkai. Separuh kiri dan kanan bilah status digeser ke dalam, dan tepinya diisi warna latar bilah
    status (diambil dari kolom tengah yang selalu kosong). Isi halaman lain tidak diubah.
    """
    w, h = im.size
    bar, m = status_shift(w, h)
    out = im.copy()
    # rekaman layar kadang menyisakan satu kolom gelap di tepi kanan; tutup dengan kolom tepat di sebelahnya saja,
    # supaya lengkung sudut yang menyentuh tepi tetap utuh
    out.paste(im.crop((w - 2, 0, w - 1, h)), (w - 1, 0))
    im = out.copy()
    fill = im.crop((w // 2, 0, w // 2 + 1, bar)).resize((m, bar))
    out.paste(im.crop((0, 0, w // 2, bar)), (m, 0))
    out.paste(im.crop((w // 2, 0, w, bar)), (w // 2 - m, 0))
    out.paste(fill, (0, 0))
    out.paste(fill, (w - m, 0))
    return out


def _font(size: int):
    """Inter dari assets/fonts proyek ini bila ada; huruf bawaan Pillow bila tidak."""
    from PIL import ImageFont

    fonts = Path(__file__).resolve().parent.parent / "assets" / "fonts"
    for name in ("Inter-SemiBold.ttf", "Inter.ttf", "Inter-Medium.ttf"):
        if (fonts / name).exists():
            font = ImageFont.truetype(str(fonts / name), size)
            try:
                font.set_variation_by_axes([600])  # Inter variabel: tebal setengah
            except Exception:
                pass
            return font
    return ImageFont.load_default()


def system_bars(im: Image.Image, top: int, bottom: int, clock: str = "09.30") -> Image.Image:
    """Gambar bilah status (jam, sinyal, WiFi, baterai) di [top] piksel teratas dan garis gestur di [bottom] piksel
    terbawah, untuk layar yang dirender dengan ruang sistem kosong. Warna ikon putih di atas latar gelap dan abu-abu
    tua di atas latar terang, seperti di ponsel sungguhan."""
    w, h = im.size
    out = im.convert("RGB").copy()
    k = 4  # supersampling
    for y0, y1, kind in ((0, top, "status"), (h - bottom, h, "gesture")):
        if y1 - y0 <= 0:
            continue
        strip = out.crop((0, y0, w, y1))
        lum = sum(ImageStat.Stat(strip.convert("L")).mean)
        ink = (255, 255, 255) if lum < 150 else (38, 44, 54)
        big = strip.resize((w * k, (y1 - y0) * k), Image.NEAREST)
        d = ImageDraw.Draw(big)
        bh = (y1 - y0) * k
        if kind == "gesture":
            pw, ph = w * k * .3, max(2 * k, bh * .16)
            d.rounded_rectangle(((w * k - pw) / 2, bh * .55 - ph / 2, (w * k + pw) / 2, bh * .55 + ph / 2), radius=ph / 2, fill=ink)
        else:
            cy, size = bh * .55, bh * .42
            font = _font(round(size * 1.3))
            d.text((w * k * .085, cy), clock, font=font, fill=ink, anchor="lm")
            # ikon disusun dari kanan ke kiri dengan lebar dan jarak yang tetap supaya tidak saling menumpuk
            right = w * k * (1 - .085)
            stroke = max(1, round(size * .13))
            # baterai: badan, isi, dan tonjolan kecil di kanan
            bw_, bht = size * 1.9, size * .95
            body = (right - bw_, cy - bht / 2, right, cy + bht / 2)
            d.rounded_rectangle(body, radius=bht * .28, outline=ink, width=stroke)
            d.rounded_rectangle((right + size * .08, cy - bht * .22, right + size * .26, cy + bht * .22), radius=size * .08, fill=ink)
            pad = stroke + size * .1
            d.rounded_rectangle((body[0] + pad, body[1] + pad, body[0] + pad + (bw_ - 2 * pad) * .8, body[3] - pad), radius=bht * .12, fill=ink)
            right = body[0] - size * .55
            # WiFi: kipas tiga busur dengan pusat yang sama, lebar 2 x jari-jari terbesar
            r0 = size * .95
            wx, wy = right - r0, cy + size * .5
            for r in (r0, r0 * .64):
                d.arc((wx - r, wy - r, wx + r, wy + r), 225, 315, fill=ink, width=stroke)
            r = r0 * .3
            d.pieslice((wx - r, wy - r, wx + r, wy + r), 225, 315, fill=ink)
            right = wx - r0 - size * .45
            # sinyal: empat batang naik, lebar total 1,1 x ukuran ikon
            bar_w, gap = size * .2, size * .1
            left = right - 4 * bar_w - 3 * gap
            for n in range(4):
                bx = left + n * (bar_w + gap)
                d.rounded_rectangle((bx, cy + size * .45 - size * (.3 + .23 * n), bx + bar_w, cy + size * .45), radius=size * .05, fill=ink)
        out.paste(big.resize((w, y1 - y0), Image.LANCZOS), (0, y0))
    return out


def layout(w: int, h: int) -> dict:
    """Ukuran bingkai untuk layar berukuran w x h piksel."""
    bez = round(w * 0.04)
    side = max(2, round(w * 0.012))
    body_w, body_h = w + 2 * bez, h + 2 * bez
    return {
        "bez": bez,
        "side": side,
        "body": (body_w, body_h),
        "size": (body_w + side, body_h),  # tombol menonjol di sisi kanan
        "radius": round(body_w * 0.12),
        "screen_radius": max(4, round(body_w * 0.12) - bez),
        "screen": (bez, bez, bez + w, bez + h),
    }


def overlay(w: int, h: int) -> Image.Image:
    """Bingkai RGBA dengan area layar transparan, untuk ditumpuk di atas video atau GIF."""
    g = layout(w, h)
    big = Image.new("RGBA", (g["size"][0] * SS, g["size"][1] * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    bw, bh = g["body"]
    side = g["side"]
    # tombol volume dan daya di sisi kanan, digambar lebih dulu agar badan menutup pangkalnya
    for top, length in ((0.20, 0.11), (0.35, 0.065)):
        y0, y1 = round(bh * top), round(bh * (top + length))
        d.rounded_rectangle(((bw - side * 2) * SS, y0 * SS, (bw + side) * SS, y1 * SS), radius=side * SS, fill=BODY)
    d.rounded_rectangle((0, 0, bw * SS - 1, bh * SS - 1), radius=g["radius"] * SS, fill=BODY, outline=RIM, width=max(1, SS))
    x0, y0, x1, y1 = (v * SS for v in g["screen"])
    hole = Image.new("L", big.size, 0)
    ImageDraw.Draw(hole).rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=g["screen_radius"] * SS, fill=255)
    big.putalpha(Image.composite(Image.new("L", big.size, 0), big.getchannel("A"), hole))
    # lubang kamera di tengah atas, di area bilah status yang kosong
    cam = max(3, round((x1 - x0) / SS * 0.028))
    cx, cy = (x0 + x1) // 2, y0 + round(cam * 1.6 * SS)
    d = ImageDraw.Draw(big)
    d.ellipse((cx - cam * SS, cy - cam * SS, cx + cam * SS, cy + cam * SS), fill=(24, 30, 44, 255))
    return big.resize(g["size"], Image.LANCZOS)


def add_bars(im: Image.Image) -> Image.Image:
    """Tambahkan ruang bilah status di atas dan ruang tipis di bawah untuk tangkapan layar tanpa bilah status.

    Bila tepi atas berwarna rata, ruang bilah status diisi warna itu; bila tepinya berupa foto atau beberapa warna,
    ruang itu dibuat putih seperti bilah status terang. Ruang bawah diisi warna
    yang paling banyak di baris terbawah. Baris tepi tidak pernah direntangkan, karena baris yang memotong teks akan
    tampak seperti garis-garis.
    """
    w, h = im.size
    top, bottom = round(h * 0.035), round(h * 0.02)
    out = Image.new("RGB", (w, h + top + bottom))
    out.paste(_bar(im.crop((0, 0, w, top)), edge=0), (0, 0))
    out.paste(im, (0, top))
    # bagian bawah selalu warna rata: di sana tepi tangkapan layar biasanya memotong teks, bukan foto
    out.paste(edge_color(im.crop((0, h - 1, w, h))), (0, top + h, w, top + h + bottom))
    return out


def _bar(strip: Image.Image, edge: int) -> Image.Image:
    """Isi ruang bilah status: warna tepi bila tepinya polos, putih bila tepinya berupa foto atau beberapa warna."""
    if max(ImageStat.Stat(strip).stddev) < 12:
        return Image.new("RGB", strip.size, edge_color(strip.crop((0, edge, strip.width, edge + 1))))
    return Image.new("RGB", strip.size, (255, 255, 255))


def edge_color(row: Image.Image) -> tuple[int, int, int]:
    """Warna yang paling sering muncul pada satu baris piksel."""
    return max(row.getcolors(row.width * row.height))[1]


def phone(screen: Image.Image, status_bar: bool | None = True) -> Image.Image:
    """Tangkapan layar di dalam bingkai ponsel, hasilnya RGBA dengan latar transparan.

    status_bar=True untuk tangkapan layar utuh dari ponsel atau emulator (ikon bilah status digeser ke tengah);
    False untuk tangkapan layar isi aplikasi saja (ruang bilah status ditambahkan); None bila layar sudah siap pakai.
    """
    if status_bar is not None:
        screen = clear_corners(screen.convert("RGB")) if status_bar else add_bars(screen.convert("RGB"))
    g = layout(*screen.size)
    out = Image.new("RGBA", g["size"], (0, 0, 0, 0))
    out.paste(screen, g["screen"][:2])
    frame = overlay(*screen.size)
    out.alpha_composite(frame)
    # sudut layar di luar lengkung ikut transparan supaya latar halaman terlihat rapi
    mask = Image.new("L", (g["size"][0] * SS, g["size"][1] * SS), 0)
    md = ImageDraw.Draw(mask)
    bw, bh = g["body"]
    md.rounded_rectangle((0, 0, bw * SS - 1, bh * SS - 1), radius=g["radius"] * SS, fill=255)
    md.rectangle((bw * SS - g["side"] * 2 * SS, 0, mask.width, mask.height), fill=0)
    mask = mask.resize(g["size"], Image.LANCZOS)
    alpha = Image.composite(out.getchannel("A").point(lambda v: 255), frame.getchannel("A"), mask)
    out.putalpha(alpha)
    return out


def with_shadow(im: Image.Image, blur: int = 10, alpha: int = 50) -> Image.Image:
    """Bayangan lembut di bawah ponsel; latar tetap transparan."""
    pad = blur * 3
    out = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    shade = Image.new("RGBA", im.size, (30, 42, 68, 0))
    shade.putalpha(im.getchannel("A").point(lambda v: v * alpha // 255))
    out.alpha_composite(shade.filter(ImageFilter.GaussianBlur(blur)), (pad, pad + blur))
    out.alpha_composite(im, (pad, pad))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Bingkai ponsel generik untuk tangkapan layar")
    ap.add_argument("out", type=Path, help="folder hasil; nama berkas sama dengan aslinya, berformat PNG")
    ap.add_argument("screens", type=Path, nargs="+")
    ap.add_argument("--width", type=int, default=360, help="lebar layar di dalam bingkai, dalam piksel")
    ap.add_argument("--no-status-bar", action="store_true", help="tangkapan layar tanpa bilah status")
    ap.add_argument("--shadow", action="store_true", help="tambahkan bayangan lembut")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for f in args.screens:
        im = Image.open(f).convert("RGB")
        im = im.resize((args.width, round(im.height * args.width / im.width)), Image.LANCZOS)
        framed = phone(im, status_bar=not args.no_status_bar)
        if args.shadow:
            framed = with_shadow(framed)
        framed.save(args.out / f"{f.stem}.png", optimize=True)
        print(args.out / f"{f.stem}.png", framed.size)


if __name__ == "__main__":
    main()
