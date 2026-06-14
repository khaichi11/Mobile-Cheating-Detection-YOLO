import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan aplikasi yang persisten (disimpan dengan SharedPreferences).
///
/// Memakai [ChangeNotifier] supaya UI ikut diperbarui begitu nilai berubah.
class SettingsService extends ChangeNotifier {
  static const _kConfidence = 'confidence_threshold';
  static const _kStability = 'stability_frames';
  static const _kSound = 'sound_enabled';
  static const _kVibration = 'vibration_enabled';
  static const _kCooldown = 'alert_cooldown_sec';
  static const _kFrontCam = 'default_front_camera';
  static const _kKeepAwake = 'keep_screen_awake';
  static const _kLogEvents = 'log_events';
  static const _kTeacherPin = 'teacher_pin';

  SharedPreferences? _prefs;

  double confidenceThreshold = 0.7;
  int stabilityFrames = 2;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int alertCooldownSec = 3;
  bool defaultFrontCamera = true;
  bool keepScreenAwake = true;
  bool logEvents = true;

  /// PIN pengajar untuk membuka akses ke Riwayat, ekspor CSV, dan Pengaturan.
  /// Kosong = belum diatur (akan diminta membuat saat pertama dibutuhkan).
  String teacherPin = '';
  bool get hasTeacherPin => teacherPin.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    confidenceThreshold = p.getDouble(_kConfidence) ?? confidenceThreshold;
    stabilityFrames = p.getInt(_kStability) ?? stabilityFrames;
    soundEnabled = p.getBool(_kSound) ?? soundEnabled;
    vibrationEnabled = p.getBool(_kVibration) ?? vibrationEnabled;
    alertCooldownSec = p.getInt(_kCooldown) ?? alertCooldownSec;
    defaultFrontCamera = p.getBool(_kFrontCam) ?? defaultFrontCamera;
    keepScreenAwake = p.getBool(_kKeepAwake) ?? keepScreenAwake;
    logEvents = p.getBool(_kLogEvents) ?? logEvents;
    teacherPin = p.getString(_kTeacherPin) ?? teacherPin;
    notifyListeners();
  }

  void setTeacherPin(String pin) {
    teacherPin = pin;
    _prefs?.setString(_kTeacherPin, pin);
    notifyListeners();
  }

  void setConfidence(double v) {
    confidenceThreshold = v;
    _prefs?.setDouble(_kConfidence, v);
    notifyListeners();
  }

  void setStability(int v) {
    stabilityFrames = v;
    _prefs?.setInt(_kStability, v);
    notifyListeners();
  }

  void setSound(bool v) {
    soundEnabled = v;
    _prefs?.setBool(_kSound, v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibrationEnabled = v;
    _prefs?.setBool(_kVibration, v);
    notifyListeners();
  }

  void setCooldown(int v) {
    alertCooldownSec = v;
    _prefs?.setInt(_kCooldown, v);
    notifyListeners();
  }

  void setDefaultFrontCamera(bool v) {
    defaultFrontCamera = v;
    _prefs?.setBool(_kFrontCam, v);
    notifyListeners();
  }

  void setKeepScreenAwake(bool v) {
    keepScreenAwake = v;
    _prefs?.setBool(_kKeepAwake, v);
    notifyListeners();
  }

  void setLogEvents(bool v) {
    logEvents = v;
    _prefs?.setBool(_kLogEvents, v);
    notifyListeners();
  }

  void resetToDefaults() {
    setConfidence(0.7);
    setStability(2);
    setSound(true);
    setVibration(true);
    setCooldown(3);
    setDefaultFrontCamera(true);
    setKeepScreenAwake(true);
    setLogEvents(true);
  }
}
