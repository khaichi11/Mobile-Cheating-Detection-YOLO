import 'gaze_direction.dart';

/// Satu kejadian terdeteksi mencontek yang dicatat ke riwayat.
class DetectionEvent {
  final GazeDirection direction;
  final double confidence;
  final DateTime time;

  DetectionEvent({
    required this.direction,
    required this.confidence,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'direction': direction.rawName,
        'confidence': confidence,
        'time': time.toIso8601String(),
      };

  factory DetectionEvent.fromJson(Map<String, dynamic> j) => DetectionEvent(
        direction: GazeDirectionInfo.fromClassName(j['direction'] as String? ?? ''),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      );
}
