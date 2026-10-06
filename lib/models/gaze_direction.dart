import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Arah pandang kepala yang dikenali model YOLO, ditambah status buatan
/// aplikasi untuk kejadian lain selama sesi: wajah tidak terlihat ([hilang]),
/// ada lebih dari satu wajah ([wajahLain]), dan aplikasi ditinggalkan
/// ([keluarAplikasi]).
///
/// Kelas model (urut sesuai metadata): atas, depan, kanan, kiri, bawah.
/// Hanya `depan` yang dianggap fokus. Arah lain adalah indikasi mencontek
/// (melihat ke luar area ujian).
enum GazeDirection { depan, atas, bawah, kiri, kanan, hilang, wajahLain, keluarAplikasi, unknown }

extension GazeDirectionInfo on GazeDirection {
  /// Petakan nama kelas mentah dari model ke enum.
  static GazeDirection fromClassName(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'depan':
      case 'front':
        return GazeDirection.depan;
      case 'atas':
      case 'up':
        return GazeDirection.atas;
      case 'bawah':
      case 'down':
        return GazeDirection.bawah;
      case 'kiri':
      case 'left':
        return GazeDirection.kiri;
      case 'kanan':
      case 'right':
        return GazeDirection.kanan;
      case 'hilang':
        return GazeDirection.hilang;
      case 'wajahlain':
        return GazeDirection.wajahLain;
      case 'keluaraplikasi':
        return GazeDirection.keluarAplikasi;
      default:
        return GazeDirection.unknown;
    }
  }

  /// Arah yang benar-benar dikeluarkan model (untuk daftar kelas).
  static const List<GazeDirection> modelClasses = [
    GazeDirection.depan,
    GazeDirection.atas,
    GazeDirection.bawah,
    GazeDirection.kiri,
    GazeDirection.kanan,
  ];

  /// Label ramah-pengguna (Bahasa Indonesia).
  String get label {
    switch (this) {
      case GazeDirection.depan:
        return 'Fokus ke depan';
      case GazeDirection.atas:
        return 'Menengadah ke atas';
      case GazeDirection.bawah:
        return 'Menunduk ke bawah';
      case GazeDirection.kiri:
        return 'Menoleh ke kiri';
      case GazeDirection.kanan:
        return 'Menoleh ke kanan';
      case GazeDirection.hilang:
        return 'Wajah tidak terlihat';
      case GazeDirection.wajahLain:
        return 'Ada wajah lain';
      case GazeDirection.keluarAplikasi:
        return 'Meninggalkan aplikasi';
      case GazeDirection.unknown:
        return 'Tidak diketahui';
    }
  }

  /// Label pendek untuk chip dan grafik.
  String get shortLabel {
    switch (this) {
      case GazeDirection.depan:
        return 'Depan';
      case GazeDirection.atas:
        return 'Atas';
      case GazeDirection.bawah:
        return 'Bawah';
      case GazeDirection.kiri:
        return 'Kiri';
      case GazeDirection.kanan:
        return 'Kanan';
      case GazeDirection.hilang:
        return 'Hilang';
      case GazeDirection.wajahLain:
        return 'Wajah lain';
      case GazeDirection.keluarAplikasi:
        return 'Keluar app';
      case GazeDirection.unknown:
        return '-';
    }
  }

  /// Nama kelas mentah (untuk log/ekspor).
  String get rawName => name;

  /// True bila arah ini dianggap indikasi mencontek (dari model).
  bool get isCheating =>
      this == GazeDirection.atas ||
      this == GazeDirection.bawah ||
      this == GazeDirection.kiri ||
      this == GazeDirection.kanan;

  /// True bila arah ini layak dicatat sebagai kejadian.
  bool get isIncident =>
      isCheating ||
      this == GazeDirection.hilang ||
      this == GazeDirection.wajahLain ||
      this == GazeDirection.keluarAplikasi;

  /// Ikon arah, pengganti emoji.
  IconData get icon {
    switch (this) {
      case GazeDirection.depan:
        return Icons.center_focus_strong_rounded;
      case GazeDirection.atas:
        return Icons.north_rounded;
      case GazeDirection.bawah:
        return Icons.south_rounded;
      case GazeDirection.kiri:
        return Icons.west_rounded;
      case GazeDirection.kanan:
        return Icons.east_rounded;
      case GazeDirection.hilang:
        return Icons.person_off_outlined;
      case GazeDirection.wajahLain:
        return Icons.group_outlined;
      case GazeDirection.keluarAplikasi:
        return Icons.exit_to_app_rounded;
      case GazeDirection.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get color {
    if (isCheating || this == GazeDirection.wajahLain || this == GazeDirection.keluarAplikasi) {
      return AppColors.danger;
    }
    if (this == GazeDirection.depan) return AppColors.safe;
    return AppColors.neutral;
  }
}
