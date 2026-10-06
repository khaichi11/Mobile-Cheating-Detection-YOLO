#!/usr/bin/env python3
"""Siapkan foto wajah dummy untuk mode demo dan beri label dengan model aplikasi.

Sumber foto: satu kolase lima pose yang dibuat pemilik proyek dengan Google
Gemini. Orangnya fiktif, bukan foto orang nyata. Kolase dipotong per pose lalu
diperbesar 4x dengan Real-ESRGAN (RealESRGAN_x4plus, lisensi BSD-3-Clause)
agar tidak pecah di layar ponsel.

Langkah:
  1. prepare  butuh torch + spandrel (+ GPU bila ada): memotong kolase dan
              memperbesar tiap panel ke --work/panel_<n>.png
  2. label    butuh ai_edge_litert + pillow + numpy: mengenali pose tiap panel
              dengan model aplikasi (gaze_yolo12n_320.tflite), menyimpan
              assets/demo/wajah_<pose>.jpg dan assets/demo/hasil_model.json

Contoh:
  python tools/make_demo_faces.py prepare --collage kolase.jpeg --weights RealESRGAN_x4plus.pth --work /tmp/wajah
  python tools/make_demo_faces.py label --work /tmp/wajah
"""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "assets/models/gaze_yolo12n_320.tflite"
OUT_DIR = ROOT / "assets/demo"
OUT_SIZE = (768, 1707)  # rasio 0,45 = layar ponsel 1080x2400, dipotong dari atas
CLASS_NAMES = {0: "atas", 1: "depan", 2: "kanan", 3: "kiri", 4: "bawah"}


def prepare(args):
    import numpy as np
    import torch
    from PIL import Image
    from spandrel import ModelLoader

    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=True)
    im = Image.open(args.collage).convert("RGB")
    a = np.asarray(im).astype(int)
    # Batas antar panel = kolom dengan perubahan warna terbesar.
    diff = np.abs(a[:, 1:] - a[:, :-1]).sum(axis=(0, 2))
    margin = im.width // (args.panels * 3)
    seams = []
    for c in np.argsort(-diff):
        if margin < c < im.width - margin and all(abs(int(c) - s) > margin for s in seams):
            seams.append(int(c))
        if len(seams) == args.panels - 1:
            break
    edges = [0] + [s + 1 for s in sorted(seams)] + [im.width]

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = ModelLoader().load_from_file(args.weights).model.to(device).eval()
    if device == "cuda":
        model = model.half()
    for i, (x0, x1) in enumerate(zip(edges[:-1], edges[1:]), start=1):
        panel = np.asarray(im.crop((x0, 0, x1, im.height))).astype(np.float32) / 255
        x = torch.from_numpy(panel).permute(2, 0, 1)[None].to(device)
        if device == "cuda":
            x = x.half()
        with torch.no_grad():
            y = model(x).clamp(0, 1)
        out = (y[0].permute(1, 2, 0).float().cpu().numpy() * 255).round().astype(np.uint8)
        Image.fromarray(out).save(work / f"panel_{i}.png")
        print(f"panel_{i}: {x1 - x0}px -> {out.shape[1]}x{out.shape[0]}")


def _detect(interp, img):
    """Jalankan model pada gambar PIL; kembalikan deteksi terbaik per kelas."""
    import numpy as np

    inp = interp.get_input_details()[0]
    out = interp.get_output_details()[0]
    size = inp["shape"][1]
    w, h = img.size
    scale = min(size / w, size / h)
    nw, nh = round(w * scale), round(h * scale)
    canvas = np.full((size, size, 3), 114, np.uint8)
    px, py = (size - nw) // 2, (size - nh) // 2
    canvas[py:py + nh, px:px + nw] = np.asarray(img.convert("RGB").resize((nw, nh)))
    interp.set_tensor(inp["index"], canvas[None].astype(np.float32) / 255.0)
    interp.invoke()
    y = interp.get_tensor(out["index"])[0]  # [9, N]
    boxes, scores = y[:4].T, y[4:].T
    if boxes.max() <= 2.0:  # koordinat ternormalisasi terhadap masukan
        boxes = boxes * size
    best = {}
    for b, s in zip(boxes, scores):
        c = int(s.argmax())
        conf = float(s[c])
        if conf < 0.25 or conf <= best.get(c, (0,))[0]:
            continue
        cx, cy, bw, bh = b
        x1, y1 = (cx - bw / 2 - px) / scale / w, (cy - bh / 2 - py) / scale / h
        x2, y2 = (cx + bw / 2 - px) / scale / w, (cy + bh / 2 - py) / scale / h
        best[c] = (conf, [max(0.0, x1), max(0.0, y1), min(1.0, x2), min(1.0, y2)])
    return sorted(
        ({"className": CLASS_NAMES[c], "confidence": round(v[0], 4),
          "box": [round(float(t), 4) for t in v[1]]} for c, v in best.items()),
        key=lambda d: -d["confidence"])


def _crop_top(img, aspect):
    """Potong bagian bawah agar rasio = [aspect]; kepala, bahu, dan meja tetap terlihat.

    Model arah pandang ini membutuhkan konteks bahu; memotong terlalu dekat ke
    wajah justru menurunkan keyakinannya.
    """
    w, h = img.size
    ch = min(h, round(w / aspect))
    return img.crop((0, 0, w, ch))


def label(args):
    from ai_edge_litert.interpreter import Interpreter
    from PIL import Image, ImageOps

    interp = Interpreter(model_path=str(MODEL), num_threads=4)
    interp.allocate_tensors()
    work = Path(args.work)
    files = [f for f in sorted(work.iterdir()) if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")]

    # Pakai gambar asli bila posenya sudah terbaca; versi cermin hanya dipakai
    # untuk kiri/kanan yang belum terisi (cermin menukar kiri dan kanan).
    picks = {}
    mirrored = {}
    for path in files:
        img = _crop_top(Image.open(path).convert("RGB"), OUT_SIZE[0] / OUT_SIZE[1])
        dets = _detect(interp, img)
        top = dets[0] if dets else None
        print(f"{path.name}: {', '.join(f'{d['className']} {d['confidence']:.2f}' for d in dets[:2]) or '-'}")
        if top and top["confidence"] > picks.get(top["className"], (0,))[0]:
            picks[top["className"]] = (top["confidence"], path, False)
        if top and top["className"] in ("kiri", "kanan"):
            m = _detect(interp, ImageOps.mirror(img))
            if m and m[0]["className"] in ("kiri", "kanan") and m[0]["className"] != top["className"]:
                mirrored[m[0]["className"]] = (m[0]["confidence"], path, True)
    for pose, cand in mirrored.items():
        picks.setdefault(pose, cand)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    size = OUT_SIZE
    shots = {}
    for pose in CLASS_NAMES.values():
        if pose not in picks:
            print("TIDAK ADA gambar untuk pose", pose)
            continue
        conf, path, flipped = picks[pose]
        img = Image.open(path).convert("RGB")
        if flipped:
            img = ImageOps.mirror(img)
        img = _crop_top(img, size[0] / size[1]).resize(size, Image.LANCZOS)
        dst = OUT_DIR / f"wajah_{pose}.jpg"
        img.save(dst, quality=86, optimize=True, progressive=True)
        shots[pose] = _detect(interp, Image.open(dst))[:3]
        print(f"-> wajah_{pose}.jpg dari {path.name}{' (cermin)' if flipped else ''}: "
              f"{shots[pose][0]['className']} {shots[pose][0]['confidence']:.2f}")
    (OUT_DIR / "hasil_model.json").write_text(json.dumps(
        {"model": MODEL.name, "imageSize": list(size), "shots": shots}, indent=2) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--collage", required=True)
    p.add_argument("--weights", required=True, help="RealESRGAN_x4plus.pth")
    p.add_argument("--work", required=True)
    p.add_argument("--panels", type=int, default=5)
    lb = sub.add_parser("label")
    lb.add_argument("--work", required=True)
    args = ap.parse_args()
    {"prepare": prepare, "label": label}[args.cmd](args)


if __name__ == "__main__":
    main()
