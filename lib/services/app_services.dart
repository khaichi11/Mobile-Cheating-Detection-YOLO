import 'alarm_service.dart';
import 'detection_log.dart';
import 'settings_service.dart';

/// Wadah sederhana untuk semua service bersama, dibuat sekali di `main`
/// lalu diteruskan ke tiap layar lewat konstruktor (tanpa paket state-management).
class AppServices {
  final SettingsService settings;
  final DetectionLog log;
  final AlarmService alarm;

  /// True bila pengajar sudah membuka kunci pada sesi ini (tidak persisten —
  /// otomatis terkunci lagi setiap aplikasi dibuka, demi keamanan).
  bool teacherUnlocked = false;

  AppServices({
    required this.settings,
    required this.log,
    required this.alarm,
  });
}
