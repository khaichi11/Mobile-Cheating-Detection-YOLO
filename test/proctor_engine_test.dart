// Uji logika ProctorEngine dengan jam palsu (tanpa kamera/plugin).

import 'dart:ui' show Rect;

import 'package:cerdas/logic/proctor_engine.dart';
import 'package:cerdas/models/exam_session.dart';
import 'package:cerdas/models/gaze_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late List<Incident> incidents;
  late EngineConfig config;
  late ProctorEngine engine;

  const depan = [Detection(GazeDirection.depan, 0.92)];
  const kiri = [Detection(GazeDirection.kiri, 0.88)];
  const kosong = <Detection>[];

  /// Kirim [frames] frame berisi [d], masing-masing berjarak 33 ms (±30 FPS).
  void feed(List<Detection> d, int frames) {
    for (var i = 0; i < frames; i++) {
      now = now.add(const Duration(milliseconds: 33));
      engine.ingest(d);
    }
  }

  setUp(() {
    now = DateTime(2026, 10, 6, 8);
    incidents = [];
    config = const EngineConfig(
      confidenceThreshold: 0.7,
      stabilityFrames: 3,
      minLookAway: Duration(milliseconds: 800),
      absentAlert: Duration(seconds: 2),
      cooldown: Duration(seconds: 3),
    );
    engine = ProctorEngine(
      config: () => config,
      onIncident: incidents.add,
      clock: () => now,
    );
  });

  test('status baru berganti setelah beberapa frame stabil', () {
    feed(depan, 2);
    expect(engine.state, DetectionState.noFace);
    feed(depan, 1);
    expect(engine.state, DetectionState.honest);
    expect(engine.status.value.direction, GazeDirection.depan);
  });

  test('deteksi di bawah ambang diabaikan', () {
    feed(const [Detection(GazeDirection.kiri, 0.5)], 10);
    expect(engine.state, DetectionState.noFace);
  });

  test('menoleh sebentar tidak memicu peringatan', () {
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    feed(depan, 5);
    feed(kiri, 15); // ±0,5 detik
    expect(engine.state, DetectionState.cheating);
    expect(incidents, isEmpty);
    expect(engine.status.value.alerting, isFalse);
  });

  test('di luar sesi (mode siaga) tidak ada alarm maupun catatan', () {
    feed(depan, 5);
    feed(kiri, 90); // ±3 detik
    expect(engine.state, DetectionState.cheating);
    expect(incidents, isEmpty);
    expect(engine.status.value.alerting, isFalse);
  });

  test('menoleh lama memicu satu kejadian lalu alarm diulang tiap jeda', () {
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    feed(depan, 5);
    feed(kiri, 40); // ±1,3 detik
    expect(incidents, hasLength(1));
    expect(incidents.first.direction, GazeDirection.kiri);
    expect(incidents.first.isNewRun, isTrue);
    expect(engine.status.value.alerting, isTrue);

    feed(kiri, 100); // +3,3 detik, lewat jeda 3 detik
    expect(incidents, hasLength(2));
    expect(incidents.last.isNewRun, isFalse, reason: 'masih rentang menoleh yang sama');
  });

  test('wajah hilang sekejap tidak membuat status berkedip', () {
    feed(depan, 5);
    feed(kosong, 3); // ±0,1 detik
    expect(engine.state, DetectionState.honest);
    feed(kosong, 12); // total ±0,5 detik
    expect(engine.state, DetectionState.noFace);
  });

  test('peringatan wajah hilang hanya saat sesi berjalan, sekali per rentang', () {
    feed(kosong, 120);
    expect(incidents, isEmpty);

    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    feed(depan, 5);
    feed(kosong, 200); // ±6,6 detik
    expect(incidents.where((i) => i.direction == GazeDirection.hilang), hasLength(1));
  });

  test('sesi menghitung durasi fokus, menoleh, dan kejadian', () {
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    feed(depan, 60); // ±2 detik
    feed(kiri, 45); // ±1,5 detik
    feed(depan, 30);
    final s = engine.endSession()!;
    expect(s.end, isNotNull);
    expect(s.focusMs, greaterThan(2500));
    expect(s.awayMs, inInclusiveRange(1300, 1700));
    expect(s.longestAwayMs, greaterThanOrEqualTo(1300));
    expect(s.incidents[GazeDirection.kiri], 1);
    expect(engine.session, isNull);
  });

  test('waktu saat dijeda tidak dihitung', () {
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    feed(depan, 30);
    final before = engine.session!.focusMs;
    now = now.add(const Duration(minutes: 5));
    engine.resumeAfterGap();
    feed(depan, 1);
    expect(engine.session!.focusMs - before, lessThan(100));
  });

  test('garis waktu menyimpan segmen per status', () {
    feed(depan, 10);
    feed(kiri, 10);
    feed(depan, 10);
    final states = engine.timeline.map((s) => s.state).toList();
    expect(states, containsAllInOrder([
      DetectionState.honest,
      DetectionState.cheating,
      DetectionState.honest,
    ]));
  });

  test('dua wajah terpisah selama lebih dari 1,5 detik dicatat sekali', () {
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    const dua = [
      Detection(GazeDirection.depan, 0.9, box: Rect.fromLTRB(0.1, 0.1, 0.4, 0.4)),
      Detection(GazeDirection.kanan, 0.85, box: Rect.fromLTRB(0.6, 0.1, 0.9, 0.4)),
    ];
    feed(dua, 30); // ±1 detik
    expect(incidents.where((i) => i.direction == GazeDirection.wajahLain), isEmpty);
    feed(dua, 60); // total ±3 detik
    expect(incidents.where((i) => i.direction == GazeDirection.wajahLain), hasLength(1));
    expect(engine.status.value.faces, 2);
  });

  test('kotak tumpang tindih pada wajah yang sama dihitung satu wajah', () {
    const sama = [
      Detection(GazeDirection.depan, 0.9, box: Rect.fromLTRB(0.30, 0.20, 0.60, 0.50)),
      Detection(GazeDirection.kanan, 0.5, box: Rect.fromLTRB(0.32, 0.21, 0.61, 0.52)),
    ];
    expect(ProctorEngine.countFaces(sama), 1);
  });

  test('meninggalkan aplikasi saat sesi dicatat beserta lamanya', () {
    engine.recordLeftApp(const Duration(seconds: 20));
    expect(incidents, isEmpty, reason: 'tanpa sesi tidak dicatat');
    engine.startSession(ExamSession(id: 's', name: 'Uji', start: now));
    engine.recordLeftApp(const Duration(milliseconds: 400));
    expect(incidents, isEmpty, reason: 'terlalu singkat');
    engine.recordLeftApp(const Duration(seconds: 12));
    expect(incidents.single.direction, GazeDirection.keluarAplikasi);
    expect(engine.session!.leftAppMs, 12000);
    expect(engine.session!.incidents[GazeDirection.keluarAplikasi], 1);
  });

  test('sisa waktu sesi berkurang dan tidak negatif', () {
    final s = ExamSession(id: 's', name: 'Uji', start: now, plannedMinutes: 1);
    expect(s.remaining(now)!.inSeconds, 60);
    expect(s.remaining(now.add(const Duration(minutes: 5))), Duration.zero);
    expect(ExamSession(id: 't', name: 'Bebas', start: now).remaining(now), isNull);
  });
}
