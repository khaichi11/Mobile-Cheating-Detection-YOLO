import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Peringatan saat ada kejadian: bunyi alarm + getaran.
///
/// Dirancang defensif: bila pemutaran audio gagal (mis. perangkat tanpa
/// audio output) aplikasi tetap berjalan tanpa crash. Pemutar dibuat saat
/// [init] agar layanan ini aman dibuat di lingkungan uji tanpa plugin.
/// Getaran memakai [HapticFeedback] bawaan Flutter (tanpa dependency tambahan).
class AlarmService {
  AudioPlayer? _player;
  bool _ready = false;

  Future<void> init() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource('sounds/alarm.wav'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Bunyikan alarm dan/atau getarkan perangkat.
  Future<void> alert({required bool sound, required bool vibrate}) async {
    if (vibrate) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {/* abaikan */}
    }
    if (sound) {
      try {
        if (!_ready) await init();
        final p = _player;
        if (p == null) return;
        await p.stop();
        await p.play(AssetSource('sounds/alarm.wav'));
      } catch (_) {/* abaikan kegagalan audio */}
    }
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
