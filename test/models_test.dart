// Unit test untuk logika murni aplikasi (tanpa kamera/native plugin).

import 'package:cerdas/models/detection_event.dart';
import 'package:cerdas/models/exam_session.dart';
import 'package:cerdas/models/gaze_direction.dart';
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

    test('arah unknown dan hilang tidak dianggap mencontek', () {
      expect(GazeDirection.unknown.isCheating, isFalse);
      expect(GazeDirection.hilang.isCheating, isFalse);
      expect(GazeDirection.hilang.isIncident, isTrue);
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

    test('JSON lama tanpa durasi/sesi tetap terbaca', () {
      final e = DetectionEvent.fromJson({
        'direction': 'kiri',
        'confidence': 0.9,
        'time': '2026-06-15T10:00:00.000',
      });
      expect(e.duration, Duration.zero);
      expect(e.sessionId, isNull);
    });
  });

  group('ExamSession', () {
    test('round-trip JSON dan rasio fokus', () {
      final s = ExamSession(
        id: 'a',
        name: 'UTS, Kelas "12A"',
        start: DateTime(2026, 10, 6, 8),
        end: DateTime(2026, 10, 6, 9),
        focusMs: 9000,
        awayMs: 1000,
        absentMs: 500,
        longestAwayMs: 800,
        incidents: {GazeDirection.kiri: 2, GazeDirection.bawah: 1},
      );
      final back = ExamSession.fromJson(s.toJson());
      expect(back.name, s.name);
      expect(back.focusRatio, closeTo(0.9, 1e-9));
      expect(back.totalIncidents, 3);
      expect(back.topDirection, GazeDirection.kiri);
      expect(back.isActive, isFalse);
    });
  });
}
