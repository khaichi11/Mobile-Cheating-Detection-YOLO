"""Susun GIF demo dari bingkai PNG test/demo_render_test.dart, di dalam bingkai ponsel generik.

Bingkai digambar di laptop (tanpa emulator), sehingga prosesnya ringan: setiap bingkai dikecilkan, diberi bilah status
dan garis gestur, lalu dibingkai ponsel. ffmpeg menyusun GIF dengan palet warna sendiri untuk setiap bingkai dan hanya
menyimpan bagian yang berubah, sehingga warna tetap sesuai aslinya (tidak pudar) dan ukuran berkas tetap kecil.

    DEMO_FRAMES=build/frames flutter test test/demo_render_test.dart
    python3 tool/render_gif.py build/frames docs/images/demo.gif
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from phone_frame import phone, system_bars  # noqa: E402

BG = (238, 243, 248)
# ruang sistem yang disisakan demo_render_test.dart (piksel logis pada layar 360 x 780)
TOP, BOTTOM = 24, 16


def framed(path: Path, width: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    scale = width / im.width
    im = system_bars(im, round(TOP * im.width / 360), round(BOTTOM * im.width / 360))
    im = im.resize((width, round(im.height * scale)), Image.LANCZOS)
    f = phone(im, status_bar=None)
    canvas = Image.new("RGB", f.size, BG)
    canvas.paste(f, (0, 0), f)
    return canvas


def main(folder: str, out: str, width: int = 300) -> None:
    root = Path(folder)
    manifest = json.loads((root / "manifest.json").read_text())
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        shots: list[tuple[Path, int]] = []
        prev = None
        for item in manifest:
            canvas = framed(root / item["file"], width)
            # bingkai yang sama berturut-turut digabung supaya GIF lebih kecil
            if prev is not None and canvas.tobytes() == prev.tobytes():
                shots[-1] = (shots[-1][0], shots[-1][1] + item["ms"])
                continue
            path = tmp / f"g{len(shots):04d}.png"
            canvas.save(path)
            shots.append((path, item["ms"]))
            prev = canvas
        lines = "".join(f"file '{p}'\nduration {ms / 1000:.3f}\n" for p, ms in shots) + f"file '{shots[-1][0]}'\n"
        (tmp / "list.txt").write_text(lines)
        graph = (
            "split[a][b];[a]palettegen=stats_mode=diff:max_colors=256[p];"
            "[b][p]paletteuse=new=1:dither=none:diff_mode=rectangle"
        )
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(tmp / "list.txt"),
             "-vf", graph, "-loop", "0", out],
            check=True,
        )
        gif = Image.open(out)
        worst = 0.0
        for i, (p, _) in enumerate(shots[: gif.n_frames]):
            gif.seek(i)
            diff = ImageChops.difference(Image.open(p).convert("RGB"), gif.convert("RGB"))
            worst = max(worst, sum(ImageStat.Stat(diff).mean) / 3)
    total = sum(ms for _, ms in shots)
    print(f"{out}: {len(shots)} bingkai, {total / 1000:.1f} detik, selisih warna terbesar {worst:.1f}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
