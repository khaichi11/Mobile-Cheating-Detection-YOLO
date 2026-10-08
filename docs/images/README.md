# Gambar dokumentasi

Tangkapan layar `01-*.png` hingga `13-*.png` dihasilkan secara otomatis dari mode demo dengan perintah berikut.

```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart
```

Folder `framed/` berisi tangkapan layar yang sama di dalam bingkai ponsel. Bingkai tersebut digambar sendiri dengan
skrip `tool/phone_frame.py` dari repo [MEIRA](https://github.com/khaichi11/MEIRA) (Apache-2.0), misalnya
`python3 tool/phone_frame.py <folder>/framed <folder>/[01][0-9]-*.png --width 300 --no-status-bar`.

Berkas `alur-cerdas.png` adalah diagram alur kerja, sedangkan `wajah-dummy.jpg` memuat lima pose wajah dummy dari
orang fiktif yang dipakai dalam mode demo.
