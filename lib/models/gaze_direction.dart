import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Arah pandang kepala yang dikenali model YOLO.
///
/// Kelas model (urut sesuai training): atas, depan, kanan, kiri, bawah.
/// Hanya `depan` yang dianggap jujur — sisanya indikasi mencontek
/// (melihat ke luar area ujian).
enum GazeDirection { depan, atas, bawah, kiri, kanan, unknown }

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
      default:
        return GazeDirection.unknown;
    }
  }

  /// Label ramah-pengguna (Bahasa Indonesia).
  String get label {
    switch (this) {
      case GazeDirection.depan:
        return 'Menghadap depan';
      case GazeDirection.atas:
        return 'Menengadah ke atas';
      case GazeDirection.bawah:
        return 'Menunduk ke bawah';
      case GazeDirection.kiri:
        return 'Menoleh ke kiri';
      case GazeDirection.kanan:
        return 'Menoleh ke kanan';
      case GazeDirection.unknown:
        return 'Tidak diketahui';
    }
  }

  /// Nama kelas mentah (untuk log/ekspor).
  String get rawName => name;

  /// True bila arah ini dianggap indikasi mencontek.
  bool get isCheating => this != GazeDirection.depan && this != GazeDirection.unknown;

  /// Ikon arah — pengganti emoji.
  IconData get icon {
    switch (this) {
      case GazeDirection.depan:
        return Icons.center_focus_strong;
      case GazeDirection.atas:
        return Icons.keyboard_arrow_up;
      case GazeDirection.bawah:
        return Icons.keyboard_arrow_down;
      case GazeDirection.kiri:
        return Icons.keyboard_arrow_left;
      case GazeDirection.kanan:
        return Icons.keyboard_arrow_right;
      case GazeDirection.unknown:
        return Icons.help_outline;
    }
  }

  Color get color => isCheating ? AppColors.danger : AppColors.safe;
}
