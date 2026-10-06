import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/proctor_engine.dart';

/// Pengaturan aplikasi yang disimpan lokal (SharedPreferences).
class SettingsService extends ChangeNotifier {
  static const _kConfidence = 'confidence_threshold';
  static const _kStability = 'stability_frames';
  static const _kMinLookAway = 'min_look_away_ms';
  static const _kAbsentAlert = 'absent_alert_sec';
  static const _kSound = 'sound_enabled';
  static const _kVibration = 'vibration_enabled';
  static const _kCooldown = 'alert_cooldown_sec';
  static const _kFrontCam = 'default_front_camera';
  static const _kKeepAwake = 'keep_screen_awake';
  static const _kLogEvents = 'log_events';
  static const _kTeacherPin = 'teacher_pin';
  static const _kSessionMinutes = 'session_minutes';

  static const double defConfidence = 0.7;
  static const int defStability = 2;
  static const int defMinLookAwayMs = 800;
  static const int defAbsentAlertSec = 5;
  static const int defCooldown = 3;
  static const int defSessionMinutes = 90;

  SharedPreferences? _prefs;

  double confidenceThreshold = defConfidence;
  int stabilityFrames = defStability;

  /// Lama menoleh minimum sebelum peringatan (milidetik).
  int minLookAwayMs = defMinLookAwayMs;

  /// Peringatan bila wajah tak terlihat selama ini (detik) saat sesi; 0 = mati.
  int absentAlertSec = defAbsentAlertSec;

  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int alertCooldownSec = defCooldown;
  bool defaultFrontCamera = true;
  bool keepScreenAwake = true;
  bool logEvents = true;

  /// Durasi sesi bawaan (menit) yang diusulkan saat memulai sesi; 0 = tanpa batas.
  int sessionMinutes = defSessionMinutes;

  /// Kosong = belum diatur (akan diminta membuat saat pertama dibutuhkan).
  String teacherPin = '';
  bool get hasTeacherPin => teacherPin.isNotEmpty;

  /// Aturan deteksi dalam bentuk yang dipakai [ProctorEngine].
  EngineConfig get engineConfig => EngineConfig(
        confidenceThreshold: confidenceThreshold,
        stabilityFrames: stabilityFrames,
        minLookAway: Duration(milliseconds: minLookAwayMs),
        absentAlert: Duration(seconds: absentAlertSec),
        cooldown: Duration(seconds: alertCooldownSec),
      );

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    confidenceThreshold = p.getDouble(_kConfidence) ?? confidenceThreshold;
    stabilityFrames = p.getInt(_kStability) ?? stabilityFrames;
    minLookAwayMs = p.getInt(_kMinLookAway) ?? minLookAwayMs;
    absentAlertSec = p.getInt(_kAbsentAlert) ?? absentAlertSec;
    soundEnabled = p.getBool(_kSound) ?? soundEnabled;
    vibrationEnabled = p.getBool(_kVibration) ?? vibrationEnabled;
    alertCooldownSec = p.getInt(_kCooldown) ?? alertCooldownSec;
    defaultFrontCamera = p.getBool(_kFrontCam) ?? defaultFrontCamera;
    keepScreenAwake = p.getBool(_kKeepAwake) ?? keepScreenAwake;
    logEvents = p.getBool(_kLogEvents) ?? logEvents;
    teacherPin = p.getString(_kTeacherPin) ?? teacherPin;
    sessionMinutes = p.getInt(_kSessionMinutes) ?? sessionMinutes;
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

  void setMinLookAway(int ms) {
    minLookAwayMs = ms;
    _prefs?.setInt(_kMinLookAway, ms);
    notifyListeners();
  }

  void setAbsentAlert(int sec) {
    absentAlertSec = sec;
    _prefs?.setInt(_kAbsentAlert, sec);
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

  void setSessionMinutes(int v) {
    sessionMinutes = v;
    _prefs?.setInt(_kSessionMinutes, v);
    notifyListeners();
  }

  void resetToDefaults() {
    setConfidence(defConfidence);
    setStability(defStability);
    setMinLookAway(defMinLookAwayMs);
    setAbsentAlert(defAbsentAlertSec);
    setSound(true);
    setVibration(true);
    setCooldown(defCooldown);
    setDefaultFrontCamera(true);
    setKeepScreenAwake(true);
    setLogEvents(true);
    setSessionMinutes(defSessionMinutes);
  }
}
