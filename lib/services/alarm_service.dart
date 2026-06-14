import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Peringatan saat terdeteksi mencontek: bunyi alarm + getaran.
///
/// Dirancang defensif — bila pemutaran audio gagal (mis. perangkat tanpa
/// audio output) aplikasi tetap berjalan tanpa crash. Getaran memakai
/// [HapticFeedback] bawaan Flutter (tanpa dependency tambahan).
class AlarmService {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource('sounds/alarm.wav'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Bunyikan alarm dan/atau getarkan perangkat.
  Future<void> alert({required bool sound, required bool vibrate}) async {
    if (vibrate) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {/* abaikan */}
    }
    if (sound) {
      try {
        if (!_ready) await init();
        await _player.stop();
        await _player.play(AssetSource('sounds/alarm.wav'));
      } catch (_) {/* abaikan kegagalan audio */}
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
