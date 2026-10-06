import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../logic/proctor_engine.dart';
import '../models/gaze_direction.dart';

/// Satu foto wajah dummy beserta hasil model untuk foto itu.
class DemoShot {
  final GazeDirection pose;
  final String asset;
  List<Detection> detections;

  DemoShot(this.pose, this.asset, [this.detections = const []]);
}

/// Mode demo: memutar foto wajah dummy (orang fiktif hasil generate) sesuai
/// skenario, lalu mengirim hasil model untuk tiap foto ke [ProctorEngine]
/// seolah-olah berasal dari kamera. Berguna untuk presentasi, uji coba tanpa
/// peserta, dan tangkapan layar dokumentasi.
///
/// Hasil model dihitung langsung di perangkat dengan `YOLO.predict` memakai
/// model yang sama dengan kamera. Bila gagal (mis. di lingkungan uji tanpa
/// plugin), dipakai hasil tersimpan di `assets/demo/hasil_model.json` yang
/// dibuat dari model yang sama oleh `tools/make_demo_faces.py`.
class DemoFeed {
  DemoFeed({required this.onFrame, this.modelPath = defaultModel});

  static const String defaultModel = 'assets/models/gaze_yolo12n_320.tflite';
  static const String _resultsAsset = 'assets/demo/hasil_model.json';

  /// Ukuran asli foto demo (semua foto berukuran sama).
  Size imageSize = const Size(768, 1707);

  final String modelPath;
  final void Function(List<Detection>) onFrame;

  /// Urutan pose dan lamanya, diputar berulang.
  static const List<(GazeDirection, int)> script = [
    (GazeDirection.depan, 4000),
    (GazeDirection.kiri, 2600),
    (GazeDirection.depan, 3000),
    (GazeDirection.bawah, 2600),
    (GazeDirection.depan, 2500),
    (GazeDirection.kanan, 2400),
    (GazeDirection.depan, 2500),
    (GazeDirection.atas, 2200),
  ];

  final Map<GazeDirection, DemoShot> shots = {
    for (final d in GazeDirectionInfo.modelClasses)
      d: DemoShot(d, 'assets/demo/wajah_${d.name}.jpg'),
  };

  final ValueNotifier<DemoShot?> current = ValueNotifier(null);

  /// True bila hasil berasal dari model di perangkat, false bila dari berkas.
  bool liveResults = false;

  Timer? _timer;
  int _step = 0;
  int _elapsedInStep = 0;
  static const int _frameMs = 66; // ±15 frame per detik

  /// Siapkan hasil model untuk semua foto.
  Future<void> prepare() async {
    await _loadSavedResults();
    try {
      final yolo = YOLO(modelPath: modelPath, task: YOLOTask.detect, useGpu: false);
      for (final shot in shots.values) {
        final bytes = (await rootBundle.load(shot.asset)).buffer.asUint8List();
        final res = await yolo.predict(bytes, confidenceThreshold: 0.25)
            .timeout(const Duration(seconds: 10));
        final list = (res['detections'] as List?) ?? const [];
        shot.detections = [
          for (final m in list)
            _toDetection(YOLOResult.fromMap(m as Map<dynamic, dynamic>)),
        ];
      }
      liveResults = true;
      await yolo.dispose();
    } catch (e) {
      debugPrint('Demo memakai hasil tersimpan: $e');
      liveResults = false;
      await _loadSavedResults();
    }
  }

  Detection _toDetection(YOLOResult r) => Detection(
        GazeDirectionInfo.fromClassName(r.className),
        r.confidence,
        box: r.normalizedBox,
      );

  Future<void> _loadSavedResults() async {
    try {
      final raw = await rootBundle.loadString(_resultsAsset);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final size = j['imageSize'] as List?;
      if (size != null) {
        imageSize = Size((size[0] as num).toDouble(), (size[1] as num).toDouble());
      }
      final items = j['shots'] as Map<String, dynamic>;
      for (final shot in shots.values) {
        final dets = (items[shot.pose.name] as List?) ?? const [];
        shot.detections = [
          for (final d in dets.cast<Map<String, dynamic>>())
            Detection(
              GazeDirectionInfo.fromClassName(d['className'] as String),
              (d['confidence'] as num).toDouble(),
              box: Rect.fromLTRB(
                (d['box'][0] as num).toDouble(),
                (d['box'][1] as num).toDouble(),
                (d['box'][2] as num).toDouble(),
                (d['box'][3] as num).toDouble(),
              ),
            ),
        ];
      }
    } catch (e) {
      debugPrint('Hasil demo tersimpan tidak terbaca: $e');
    }
  }

  void start() {
    _timer?.cancel();
    _step = 0;
    _elapsedInStep = 0;
    current.value = shots[script.first.$1];
    _timer = Timer.periodic(const Duration(milliseconds: _frameMs), (_) => _tick());
  }

  void _tick() {
    _elapsedInStep += _frameMs;
    if (_elapsedInStep >= script[_step].$2) {
      _elapsedInStep = 0;
      _step = (_step + 1) % script.length;
      current.value = shots[script[_step].$1];
    }
    onFrame(current.value?.detections ?? const []);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    current.dispose();
  }
}
