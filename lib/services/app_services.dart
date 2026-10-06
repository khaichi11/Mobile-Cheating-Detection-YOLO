import 'alarm_service.dart';
import 'detection_log.dart';
import 'session_store.dart';
import 'settings_service.dart';

/// Wadah sederhana untuk semua service bersama, dibuat sekali di `main`
/// lalu diteruskan ke tiap layar lewat konstruktor (tanpa paket state-management).
class AppServices {
  final SettingsService settings;
  final DetectionLog log;
  final SessionStore sessions;
  final AlarmService alarm;

  /// Kunci pengajar terbuka sampai waktu ini (tidak persisten). Terkunci lagi
  /// otomatis 60 detik setelah PIN dimasukkan, saat sesi dimulai, dan setiap
  /// aplikasi dibuka, agar kunci tidak tertinggal terbuka untuk peserta.
  DateTime? teacherUnlockedUntil;

  static const Duration teacherUnlockWindow = Duration(seconds: 60);

  bool get teacherUnlocked {
    final until = teacherUnlockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void unlockTeacher() =>
      teacherUnlockedUntil = DateTime.now().add(teacherUnlockWindow);

  void lockTeacher() => teacherUnlockedUntil = null;

  AppServices({
    required this.settings,
    required this.log,
    required this.sessions,
    required this.alarm,
  });
}
