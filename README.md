# Deteksi Mencontek — Aplikasi Mobile (Flutter + YOLO)

Aplikasi Android untuk **memantau arah pandang peserta ujian secara real-time** dan
menandai indikasi mencontek. Model YOLO (TensorFlow Lite) berjalan **langsung di
perangkat** (luring/offline) — tidak ada gambar yang dikirim ke server.

Saat pandangan peserta menjauh dari layar (menengadah, menunduk, menoleh kiri/kanan)
secara stabil, aplikasi memunculkan peringatan visual, **membunyikan alarm**, dan
**menggetarkan perangkat**, lalu mencatat kejadiannya ke riwayat.

> Ditujukan untuk pengawasan ujian yang sah/berizin dan kebutuhan edukasi. Gunakan
> secara bertanggung jawab dan transparan kepada peserta.

<!-- Letakkan banner di docs/images/banner.png (opsional) -->
<!-- ![Banner](docs/images/banner.png) -->

---

## Tangkapan Layar

> Taruh gambar di folder [`docs/images/`](docs/images/) lalu rename sesuai nama di
> bawah — gambar akan otomatis tampil di sini. Panduan ada di
> [docs/images/README.md](docs/images/README.md).

| Deteksi | Terdeteksi Mencontek | Riwayat & Statistik |
|---|---|---|
| ![Deteksi](docs/images/01-deteksi.png) | ![Mencontek](docs/images/02-mencontek.png) | ![Riwayat](docs/images/03-riwayat.png) |

| Pengaturan | Tentang | Menu |
|---|---|---|
| ![Pengaturan](docs/images/04-pengaturan.png) | ![Tentang](docs/images/05-tentang.png) | ![Menu](docs/images/06-menu.png) |

---

## Daftar Isi

1. [Fitur Utama](#1-fitur-utama)
2. [Alur Penggunaan (Guru & Siswa)](#2-alur-penggunaan-guru--siswa)
3. [Cara Kerja](#3-cara-kerja)
4. [Kelas yang Dikenali](#4-kelas-yang-dikenali)
5. [Menu & Layar Aplikasi](#5-menu--layar-aplikasi)
6. [Prasyarat](#6-prasyarat)
7. [Instalasi & Menjalankan](#7-instalasi--menjalankan)
8. [Build APK](#8-build-apk)
9. [Konfigurasi (Pengaturan dalam Aplikasi)](#9-konfigurasi-pengaturan-dalam-aplikasi)
10. [Model YOLO](#10-model-yolo)
11. [Struktur Proyek](#11-struktur-proyek)
12. [Izin (Permissions)](#12-izin-permissions)
13. [Troubleshooting](#13-troubleshooting)
14. [Kredit](#14-kredit)

---

## 1. Fitur Utama

| Fitur | Keterangan |
|---|---|
| Deteksi arah pandang real-time | Model YOLO mengenali 5 arah kepala langsung dari kamera |
| Peringatan multi-mode | Banner visual + alarm suara + getar saat terdeteksi mencontek |
| Pencatatan riwayat | Setiap kejadian (arah, confidence, waktu) tersimpan otomatis |
| Statistik sesi | Total peringatan, durasi sesi, rincian per arah, kejadian terakhir |
| Ekspor CSV | Salin seluruh riwayat sebagai CSV untuk dianalisis di luar aplikasi |
| Akses pengajar (PIN) | Riwayat, ekspor CSV, dan Pengaturan dikunci PIN agar peserta tak bisa mengubahnya |
| Pengaturan lengkap | Atur ambang keyakinan, frame stabil, jeda alarm, suara, getar, kamera |
| Menu navigasi | Drawer untuk berpindah antara Deteksi, Riwayat, Pengaturan, Tentang |
| Layar tetap menyala | Cegah layar tidur selama pemantauan ujian |
| Berjalan luring | Semua inferensi di perangkat; privasi terjaga, tanpa internet |

---

## 2. Alur Penggunaan (Guru & Siswa)

Aplikasi dirancang untuk dipegang **di sisi peserta** selama ujian, tetapi data
sensitif tetap aman karena dikunci PIN pengajar.

**Sebelum ujian (pengajar):**

1. Buka aplikasi, ketuk ikon menu, pilih **Pengaturan** (akan diminta membuat
   **PIN Pengajar** saat pertama kali).
2. Atur ambang keyakinan, suara, getar, dan sensitivitas bila perlu.
3. Ketuk **Kunci mode pengajar** dari menu agar kembali ke mode peserta.

**Selama ujian (peserta):**

4. Perangkat menampilkan kamera + status deteksi. Peserta **tidak bisa** membuka
   Riwayat, mengekspor data, atau mengubah Pengaturan tanpa PIN.
5. Saat pandangan menjauh dari layar secara stabil, aplikasi memberi peringatan
   (banner + alarm + getar) dan mencatat kejadian.

**Setelah ujian (pengajar):**

6. Buka menu, pilih **Riwayat & Statistik**, masukkan **PIN Pengajar**.
7. Tinjau daftar kejadian dan rekap per arah, lalu **Salin CSV** untuk dokumentasi.
8. Kunci kembali bila perangkat akan dipakai peserta lain.

> Ekspor CSV, hapus riwayat, dan seluruh Pengaturan hanya bisa diakses dalam
> **mode pengajar**. Mode terkunci kembali otomatis setiap aplikasi ditutup.

---

## 3. Cara Kerja

```
Kamera  ->  YOLOView (ultralytics_yolo)  ->  Deteksi arah kepala per frame
                                              |
                                              v
                              Penstabilan (N frame berturut sama)
                                              |
                 +----------------------------+----------------------------+
                 v                                                         v
          arah = "depan"                                  arah = atas/bawah/kiri/kanan
          -> status JUJUR                                  -> status MENCONTEK
                                                           -> alarm + getar (dengan cooldown)
                                                           -> catat ke Riwayat
```

- **Penstabilan**: status hanya berubah setelah arah yang sama muncul beberapa frame
  berturut-turut (default 2). Mengurangi kedip akibat satu frame meleset.
- **Cooldown alarm**: setelah berbunyi, alarm tidak berbunyi lagi selama beberapa detik
  (default 3) agar tidak terus-menerus.
- **Ambang keyakinan**: deteksi di bawah ambang (default 70%) dianggap "wajah tidak
  terdeteksi", bukan mencontek.

---

## 4. Kelas yang Dikenali

Model dilatih untuk lima arah pandang kepala:

| Kelas (model) | Label aplikasi | Status |
|---|---|---|
| `depan` | Menghadap depan | Jujur |
| `atas` | Menengadah ke atas | Indikasi mencontek |
| `bawah` | Menunduk ke bawah | Indikasi mencontek |
| `kiri` | Menoleh ke kiri | Indikasi mencontek |
| `kanan` | Menoleh ke kanan | Indikasi mencontek |

Pemetaan ini didefinisikan di [`lib/models/gaze_direction.dart`](lib/models/gaze_direction.dart).
Hanya `depan` yang dianggap jujur.

---

## 5. Menu & Layar Aplikasi

Menu dibuka lewat ikon menu di kiri atas layar deteksi. Ikon gembok menandai
layar yang memerlukan PIN pengajar.

| Layar | Akses | Isi |
|---|---|---|
| **Deteksi** | Terbuka | Kamera langsung, bingkai wajah, indikator FPS, banner status, tombol ganti kamera, toggle debug |
| **Riwayat & Statistik** | PIN pengajar | Kartu statistik, rincian per arah, daftar kejadian, salin CSV, hapus riwayat |
| **Pengaturan** | PIN pengajar | Ambang keyakinan, frame stabil, jeda alarm, suara, getar, kamera default, layar tetap menyala, ubah PIN |
| **Tentang** | Terbuka | Penjelasan cara kerja, daftar kelas, catatan privasi, kredit |

---

## 6. Prasyarat

- **Flutter SDK** 3.41+ (Dart 3.9+) — diuji dengan Flutter 3.41.1 stable.
- **Android SDK** + perangkat/emulator Android (disarankan perangkat fisik berkamera).
- Android **minSdk** mengikuti default Flutter; GPU delegate dipakai bila tersedia.

Cek instalasi:

```bash
flutter --version
flutter doctor
```

---

## 7. Instalasi & Menjalankan

```bash
# 1) Masuk ke folder proyek
cd Comvis/Mobile-Cheating-Detection-YOLO

# 2) Ambil dependensi
flutter pub get

# 3) Hubungkan perangkat Android (USB debugging) lalu cek
flutter devices

# 4) Jalankan
flutter run
```

Aplikasi akan meminta izin kamera saat pertama dibuka. Berikan izin agar deteksi aktif.

---

## 8. Build APK

```bash
# APK debug (cepat, untuk uji)
flutter build apk --debug

# APK release (terbagi per-ABI, ukuran lebih kecil)
flutter build apk --release --split-per-abi
```

Hasil ada di `build/app/outputs/flutter-apk/`.

---

## 9. Konfigurasi (Pengaturan dalam Aplikasi)

Semua dapat diubah di layar **Pengaturan** dan tersimpan otomatis (SharedPreferences):

| Pengaturan | Default | Fungsi |
|---|---|---|
| Ambang keyakinan | 70% | Confidence minimal agar deteksi dihitung |
| Frame stabil | 2 | Jumlah frame berturut sebelum status berubah |
| Jeda antar peringatan | 3 dtk | Cooldown agar alarm tak berbunyi terus |
| Suara alarm | aktif | Bunyikan alarm saat terdeteksi mencontek |
| Getar | aktif | Getarkan perangkat saat terdeteksi |
| Catat riwayat | aktif | Simpan setiap kejadian ke Riwayat |
| Mulai dengan kamera depan | aktif | Kamera default saat aplikasi dibuka |
| Layar tetap menyala | aktif | Cegah layar tidur selama pemantauan |

---

## 10. Model YOLO

- **File**: `android/app/src/main/assets/best_float16(revfix).tflite`
- **Tugas**: `detect` (deteksi arah kepala)
- **Kelas**: `atas`, `depan`, `kanan`, `kiri`, `bawah`
- **Pelatihan**: lihat [`Training_Yolo/`](Training_Yolo/) (notebook YOLOv12n).

**Mengganti model:** taruh `.tflite` baru di folder `assets` Android, lalu ubah nama
file pada konstanta `_model` di [`lib/screens/detection_screen.dart`](lib/screens/detection_screen.dart).
Jika nama kelas berubah, sesuaikan pemetaan di
[`lib/models/gaze_direction.dart`](lib/models/gaze_direction.dart).

---

## 11. Struktur Proyek

```
lib/
  main.dart                      Entry point, tema, inisialisasi service
  theme/
    app_theme.dart               Palet warna & ThemeData (tanpa emoji)
  models/
    gaze_direction.dart          5 kelas arah + label/ikon/status
    detection_event.dart         Satu kejadian (arah, confidence, waktu)
  services/
    app_services.dart            Wadah service bersama
    settings_service.dart        Pengaturan persisten (SharedPreferences)
    alarm_service.dart           Alarm suara (audioplayers) + getar (haptics)
    detection_log.dart           Riwayat + statistik, persisten
  screens/
    detection_screen.dart        Layar utama: kamera + YOLO + status
    history_screen.dart          Riwayat & statistik
    settings_screen.dart         Pengaturan
    about_screen.dart            Tentang
  widgets/
    app_drawer.dart              Menu navigasi
    status_banner.dart           Banner status bawah
    stat_card.dart               Kartu statistik
assets/
  sounds/alarm.wav               Nada alarm (dibuat oleh tools/gen_alarm.py)
tools/
  gen_alarm.py                   Skrip pembuat alarm.wav
docs/images/                     Tempat tangkapan layar untuk README
```

---

## 12. Izin (Permissions)

Dideklarasikan di `android/app/src/main/AndroidManifest.xml`:

- `CAMERA` — wajib, untuk deteksi.
- `WAKE_LOCK` — agar layar tetap menyala selama pemantauan.

---

## 13. Troubleshooting

| Gejala | Solusi |
|---|---|
| Layar minta izin kamera terus | Buka Setelan Android > Aplikasi > izin kamera, aktifkan manual |
| Deteksi tidak muncul | Pastikan pencahayaan cukup; turunkan "Ambang keyakinan" di Pengaturan |
| Status berkedip-kedip | Naikkan "Frame stabil" di Pengaturan |
| Alarm berbunyi terlalu sering | Naikkan "Jeda antar peringatan" |
| Tidak ada suara | Pastikan "Suara alarm" aktif dan volume media tidak senyap |
| FPS rendah | GPU delegate sudah aktif; pakai perangkat lebih baru atau turunkan resolusi |
| Lupa PIN pengajar | Hapus data aplikasi via Setelan Android > Aplikasi > Penyimpanan > Hapus data (riwayat & PIN ikut terhapus), lalu buat PIN baru |
| `flutter pub get` gagal | Cek koneksi internet & versi Flutter (`flutter doctor`) |

---

## 14. Kredit

- **Model YOLO**: dilatih oleh Khairuramdhani dan Naufal Arya Pradipta (YOLOv12n).
- **Aplikasi**: dibangun dengan Flutter, `ultralytics_yolo`, `audioplayers`,
  `shared_preferences`, dan `wakelock_plus`.
