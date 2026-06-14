"""Generate a short two-tone alarm beep (16-bit PCM WAV, mono).

Dipakai sebagai aset suara peringatan saat terdeteksi mencontek.
Jalankan: python3 tools/gen_alarm.py
Output  : assets/sounds/alarm.wav
"""
import math
import os
import struct
import wave

SAMPLE_RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "alarm.wav")


def tone(freq, ms, volume=0.6):
    """Hasilkan satu nada sinus dengan fade in/out singkat agar tidak 'klik'."""
    n = int(SAMPLE_RATE * ms / 1000)
    fade = int(SAMPLE_RATE * 0.005)  # 5 ms fade
    out = []
    for i in range(n):
        amp = volume
        if i < fade:
            amp *= i / fade
        elif i > n - fade:
            amp *= (n - i) / fade
        out.append(amp * math.sin(2 * math.pi * freq * i / SAMPLE_RATE))
    return out


def main():
    samples = []
    # Pola alarm: nada tinggi-rendah diulang dua kali (mirip sirine pendek).
    for _ in range(2):
        samples += tone(1100, 140)
        samples += tone(720, 140)
    samples += tone(1100, 180)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(os.path.normpath(OUT), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)
    print(f"wrote {os.path.normpath(OUT)} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")


if __name__ == "__main__":
    main()
