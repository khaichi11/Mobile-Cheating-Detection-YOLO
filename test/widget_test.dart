// Unit test untuk logika murni aplikasi (tanpa kamera/native plugin).

import 'package:buatcomvis/models/detection_event.dart';
import 'package:buatcomvis/models/gaze_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GazeDirection', () {
    test('hanya "depan" yang dianggap jujur', () {
      expect(GazeDirectionInfo.fromClassName('depan').isCheating, isFalse);
      for (final c in ['atas', 'bawah', 'kiri', 'kanan']) {
        expect(GazeDirectionInfo.fromClassName(c).isCheating, isTrue,
            reason: '$c seharusnya indikasi mencontek');
      }
    });

    test('pemetaan nama kelas tidak peka huruf besar/spasi', () {
      expect(GazeDirectionInfo.fromClassName('  KIRI '), GazeDirection.kiri);
      expect(GazeDirectionInfo.fromClassName('xxx'), GazeDirection.unknown);
    });

    test('arah unknown tidak memicu mencontek', () {
      expect(GazeDirection.unknown.isCheating, isFalse);
    });
  });

  group('DetectionEvent', () {
    test('round-trip JSON mempertahankan data', () {
      final e = DetectionEvent(
        direction: GazeDirection.kanan,
        confidence: 0.83,
        time: DateTime(2026, 6, 15, 10, 30, 0),
      );
      final back = DetectionEvent.fromJson(e.toJson());
      expect(back.direction, GazeDirection.kanan);
      expect(back.confidence, closeTo(0.83, 1e-9));
      expect(back.time, e.time);
    });
  });
}
