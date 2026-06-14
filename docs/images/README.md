# Folder gambar dokumentasi

Letakkan tangkapan layar / gambar dokumentasi di folder ini, lalu **rename** sesuai
nama berikut supaya otomatis muncul di `README.md` utama:

| Nama file | Isi yang disarankan |
|---|---|
| `01-deteksi.png` | Layar utama deteksi (kamera + banner status) |
| `02-mencontek.png` | Saat status "Terdeteksi Mencontek" (banner merah) |
| `03-riwayat.png` | Layar Riwayat & Statistik |
| `04-pengaturan.png` | Layar Pengaturan |
| `05-tentang.png` | Layar Tentang |
| `06-menu.png` | Menu navigasi (drawer) terbuka |
| `banner.png` | Banner header (opsional, untuk bagian atas README) |

Format yang didukung: `.png`, `.jpg`. Setelah file diletakkan dan di-rename,
cukup `git add docs/images && git commit && git push`. Gambar akan langsung
tampil di README tanpa perlu mengubah teks.
