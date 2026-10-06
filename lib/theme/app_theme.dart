import 'package:flutter/material.dart';

/// Palet "lembar ujian": kertas, tinta, dan garis tipis.
///
/// Warna hanya dipakai untuk status (hijau fokus, oranye indikasi, abu-abu
/// wajah tidak terlihat). Tidak ada gradien, kartu bayangan, atau ikon hias.
class AppColors {
  /// Kertas dan tinta.
  static const Color background = Color(0xFFF4F2EB);
  static const Color surface = Color(0xFFFBFAF6);
  static const Color surfaceAlt = Color(0xFFEAE6DB);
  static const Color line = Color(0xFFD9D4C7);
  static const Color lineStrong = Color(0xFFB9B2A2);

  static const Color textPrimary = Color(0xFF191917);
  static const Color textSecondary = Color(0xFF66645D);
  static const Color textFaint = Color(0xFF9A978D);

  /// Tombol utama memakai tinta hitam.
  static const Color primary = Color(0xFF191917);
  static const Color onPrimary = Color(0xFFF4F2EB);

  /// Status.
  static const Color safe = Color(0xFF23804F); // fokus ke depan
  static const Color danger = Color(0xFFC9541F); // indikasi
  static const Color neutral = Color(0xFF8A877E); // wajah tidak terlihat
  static const Color warning = Color(0xFFA9781C); // keyakinan rendah

  /// Lapisan gelap di atas video kamera.
  static const Color scrim = Color(0x99000000);
  static const Color onScrim = Color(0xFFF4F2EB);
  static const Color onScrimSoft = Color(0xB3F4F2EB);

  /// Warna berdasarkan tingkat keyakinan model.
  static Color forConfidence(double c) {
    if (c >= 0.85) return safe;
    if (c >= 0.7) return warning;
    return danger;
  }
}

/// Poppins untuk judul, Inter untuk teks isi dan angka.
class AppFonts {
  static const String display = 'Poppins';
  static const String body = 'Inter';
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.body,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.safe,
        onSecondary: AppColors.onPrimary,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceAlt,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
      ),
    );
    const r = BorderRadius.all(Radius.circular(6));
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(color: AppColors.line),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(fontFamily: AppFonts.body, color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body, fontWeight: FontWeight.w600, fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: r),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.textPrimary, width: 1.2),
          textStyle: const TextStyle(
              fontFamily: AppFonts.body, fontWeight: FontWeight.w600, fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: r),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onPrimary : AppColors.textFaint),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.surfaceAlt),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.lineStrong),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.textPrimary,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.textPrimary,
        overlayColor: Color(0x1A191917),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        trackHeight: 3,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.textPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.line,
        labelStyle: TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        labelStyle: TextStyle(fontFamily: AppFonts.body, fontSize: 13, color: AppColors.textPrimary),
        secondaryLabelStyle:
            TextStyle(fontFamily: AppFonts.body, fontSize: 13, color: AppColors.onPrimary),
        showCheckmark: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: TextStyle(color: AppColors.textPrimary),
        border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lineStrong)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lineStrong)),
        focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 2)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.textPrimary),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.textPrimary),
    );
  }
}

/// Gaya teks angka (FPS, waktu, persentase): Inter dengan angka tabular
/// agar lebarnya tidak berubah-ubah saat nilainya berganti.
TextStyle monoStyle({
  double size = 14,
  Color color = AppColors.textPrimary,
  FontWeight weight = FontWeight.w500,
}) =>
    TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Gaya judul (Poppins).
TextStyle displayStyle({
  double size = 20,
  Color color = AppColors.textPrimary,
  FontWeight weight = FontWeight.w600,
}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.25,
    );
