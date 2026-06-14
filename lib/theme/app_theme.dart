import 'package:flutter/material.dart';

/// Palet warna & tema aplikasi.
///
/// Satu sumber kebenaran untuk warna agar konsisten di semua layar.
/// Tidak memakai emoji — status divisualkan lewat warna + Material Icons.
class AppColors {
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF171C24);
  static const Color surfaceAlt = Color(0xFF1F2630);
  static const Color primary = Color(0xFF3B82F6);
  static const Color onPrimary = Colors.white;

  /// Status deteksi
  static const Color safe = Color(0xFF10B981); // jujur / menghadap depan
  static const Color danger = Color(0xFFEF4444); // terdeteksi mencontek
  static const Color neutral = Color(0xFF8B5CF6); // wajah tidak terdeteksi
  static const Color warning = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Warna berdasarkan tingkat confidence.
  static Color forConfidence(double c) {
    if (c > 0.9) return safe;
    if (c > 0.8) return const Color(0xFF34D399);
    if (c > 0.7) return warning;
    if (c > 0.6) return const Color(0xFFFB923C);
    return danger;
  }
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
      dividerColor: Colors.white12,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
      ),
    );
  }
}
