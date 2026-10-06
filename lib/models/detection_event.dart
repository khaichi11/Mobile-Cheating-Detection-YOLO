import 'gaze_direction.dart';

/// Satu kejadian (indikasi mencontek atau wajah hilang) yang dicatat ke riwayat.
class DetectionEvent {
  final GazeDirection direction;
  final double confidence;
  final DateTime time;

  /// Lama kondisi berlangsung sampai peringatan dipicu.
  final Duration duration;

  /// Sesi ujian tempat kejadian terjadi; null bila di luar sesi.
  final String? sessionId;

  DetectionEvent({
    required this.direction,
    required this.confidence,
    required this.time,
    this.duration = Duration.zero,
    this.sessionId,
  });

  Map<String, dynamic> toJson() => {
        'direction': direction.rawName,
        'confidence': confidence,
        'time': time.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        if (sessionId != null) 'sessionId': sessionId,
      };

  factory DetectionEvent.fromJson(Map<String, dynamic> j) => DetectionEvent(
        direction: GazeDirectionInfo.fromClassName(j['direction'] as String? ?? ''),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
        sessionId: j['sessionId'] as String?,
      );
}
