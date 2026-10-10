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

  /// Percobaan PIN yang salah berturut-turut. Setiap lima kali salah, pintu PIN
  /// dikunci sementara (30 detik, lalu dua kali lipat sampai 5 menit) supaya PIN
  /// 4 digit tidak bisa ditebak satu per satu oleh peserta selama ujian.
  int pinFailures = 0;
  DateTime? pinLockedUntil;

  static const Duration _firstPinLock = Duration(seconds: 30);
  static const Duration _maxPinLock = Duration(minutes: 5);

  Duration pinLockRemaining([DateTime? now]) {
    final until = pinLockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void registerPinFailure([DateTime? now]) {
    pinFailures++;
    if (pinFailures % 5 != 0) return;
    final round = pinFailures ~/ 5 - 1;
    final lock = _firstPinLock * (1 << round.clamp(0, 10));
    pinLockedUntil = (now ?? DateTime.now()).add(lock > _maxPinLock ? _maxPinLock : lock);
  }

  void registerPinSuccess() {
    pinFailures = 0;
    pinLockedUntil = null;
  }

  AppServices({
    required this.settings,
    required this.log,
    required this.sessions,
    required this.alarm,
  });
}
