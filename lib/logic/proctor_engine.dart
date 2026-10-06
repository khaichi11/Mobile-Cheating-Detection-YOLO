import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../models/exam_session.dart';
import '../models/gaze_direction.dart';

/// Status yang ditampilkan ke pengguna.
enum DetectionState { noFace, honest, cheating }

/// Satu hasil deteksi yang sudah dipetakan ke arah pandang.
class Detection {
  final GazeDirection direction;
  final double confidence;

  /// Kotak wajah ternormalisasi (0..1) relatif terhadap gambar sumber.
  final Rect? box;

  const Detection(this.direction, this.confidence, {this.box});
}

/// Aturan deteksi yang bisa diatur pengajar.
class EngineConfig {
  final double confidenceThreshold;
  final int stabilityFrames;
  final Duration minLookAway;
  final Duration absentAlert;
  final Duration cooldown;

  const EngineConfig({
    this.confidenceThreshold = 0.7,
    this.stabilityFrames = 2,
    this.minLookAway = const Duration(milliseconds: 800),
    this.absentAlert = const Duration(seconds: 5),
    this.cooldown = const Duration(seconds: 3),
  });
}

/// Potret status terkini untuk UI.
@immutable
class LiveStatus {
  final DetectionState state;
  final GazeDirection direction;
  final double confidence;

  /// Lama status saat ini sudah berlangsung.
  final Duration heldFor;

  /// True selama peringatan aktif (menoleh melewati batas waktu).
  final bool alerting;

  final Rect? box;

  /// Jumlah wajah terpisah yang terlihat pada frame terakhir.
  final int faces;

  const LiveStatus({
    this.state = DetectionState.noFace,
    this.direction = GazeDirection.unknown,
    this.confidence = 0,
    this.heldFor = Duration.zero,
    this.alerting = false,
    this.box,
    this.faces = 0,
  });

  static const LiveStatus initial = LiveStatus();
}

/// Potongan garis waktu dengan satu status.
class TimelineSegment {
  final DetectionState state;
  final DateTime start;
  DateTime end;

  TimelineSegment(this.state, this.start, this.end);
}

/// Kejadian yang memicu peringatan.
class Incident {
  final GazeDirection direction;
  final double confidence;
  final Duration heldFor;
  final DateTime time;

  /// True untuk kejadian pertama pada satu rentang menoleh (dicatat ke riwayat);
  /// false untuk pengulangan alarm saat rentang yang sama masih berlangsung.
  final bool isNewRun;

  const Incident({
    required this.direction,
    required this.confidence,
    required this.heldFor,
    required this.time,
    required this.isNewRun,
  });
}

/// Mesin pengawas: menerima deteksi per frame, menstabilkannya, menghitung
/// durasi tiap status, dan memutuskan kapan peringatan dibunyikan.
///
/// Sengaja tidak bergantung pada widget atau plugin kamera agar mudah diuji
/// dan bisa dipakai bersama oleh kamera langsung maupun mode demo.
/// UI hanya diberi tahu saat status berubah (atau paling sering ~10 kali per
/// detik untuk angka keyakinan), bukan pada setiap frame kamera.
class ProctorEngine {
  ProctorEngine({
    required EngineConfig Function() config,
    required void Function(Incident) onIncident,
    DateTime Function()? clock,
    this.timelineWindow = const Duration(seconds: 90),
  })  : _config = config,
        _onIncident = onIncident,
        _now = clock ?? DateTime.now;

  final EngineConfig Function() _config;
  final void Function(Incident) _onIncident;
  final DateTime Function() _now;
  final Duration timelineWindow;

  /// Status terkini untuk UI.
  final ValueNotifier<LiveStatus> status = ValueNotifier(LiveStatus.initial);

  /// Garis waktu beberapa detik terakhir (terlama di depan).
  final List<TimelineSegment> timeline = [];

  ExamSession? _session;
  ExamSession? get session => _session;

  // Kandidat yang sedang diuji kestabilannya.
  GazeDirection _pendingDir = GazeDirection.unknown;
  int _pendingCount = 0;
  DateTime? _pendingSince;

  // Status stabil saat ini.
  GazeDirection _stableDir = GazeDirection.unknown;
  DateTime? _stableSince;
  double _confidence = 0;
  Rect? _box;

  DateTime? _lastUpdate;
  DateTime? _lastAlarm;
  bool _runLogged = false;
  DateTime? _lastNotify;

  // Lebih dari satu wajah terlihat.
  int _faces = 0;
  DateTime? _multiSince;
  bool _multiLogged = false;

  /// Jumlah frame yang diproses sejak awal (untuk info teknis).
  int frames = 0;

  static const Duration _notifyInterval = Duration(milliseconds: 100);
  static const Duration _minAbsentDebounce = Duration(milliseconds: 300);

  /// Wajah lain harus terlihat selama ini sebelum dicatat.
  static const Duration multiFaceHold = Duration(milliseconds: 1500);

  /// Meninggalkan aplikasi lebih singkat dari ini diabaikan (mis. notifikasi sekilas).
  static const Duration minLeaveApp = Duration(seconds: 1);

  DetectionState _stateOf(GazeDirection d) {
    if (d == GazeDirection.unknown || d == GazeDirection.hilang) {
      return DetectionState.noFace;
    }
    return d.isCheating ? DetectionState.cheating : DetectionState.honest;
  }

  DetectionState get state => _stateOf(_stableDir);

  /// Mulai sesi ujian baru. Akumulasi durasi dihitung sejak titik ini.
  void startSession(ExamSession s) {
    _advance(_now());
    _session = s;
  }

  /// Akhiri sesi aktif dan kembalikan ringkasannya.
  ExamSession? endSession() {
    final s = _session;
    if (s == null) return null;
    _advance(_now());
    s.end = _now();
    _session = null;
    return s;
  }

  /// Kosongkan status (mis. saat ganti kamera atau keluar dari demo).
  void reset() {
    _pendingDir = GazeDirection.unknown;
    _pendingCount = 0;
    _pendingSince = null;
    _stableDir = GazeDirection.unknown;
    _stableSince = null;
    _confidence = 0;
    _box = null;
    _lastUpdate = null;
    _runLogged = false;
    _faces = 0;
    _multiSince = null;
    _multiLogged = false;
    timeline.clear();
    status.value = LiveStatus.initial;
  }

  /// Catat bahwa aplikasi ditinggalkan selama [away] ketika sesi berjalan
  /// (mis. peserta membuka aplikasi lain). Dipanggil saat aplikasi kembali aktif.
  void recordLeftApp(Duration away) {
    final s = _session;
    if (s == null || away < minLeaveApp) return;
    s.leftAppMs += away.inMilliseconds;
    s.incidents[GazeDirection.keluarAplikasi] = (s.incidents[GazeDirection.keluarAplikasi] ?? 0) + 1;
    final now = _now();
    _lastAlarm = now;
    _onIncident(Incident(
      direction: GazeDirection.keluarAplikasi,
      confidence: 0,
      heldFor: away,
      time: now,
      isNewRun: true,
    ));
  }

  /// Jumlah wajah terpisah (kotak yang tidak saling tumpang tindih).
  static int countFaces(List<Detection> dets) {
    final boxes = <Rect>[];
    var withoutBox = 0;
    for (final d in dets) {
      final b = d.box;
      if (b == null) {
        withoutBox = 1;
        continue;
      }
      if (boxes.every((o) => _iou(o, b) < 0.3)) boxes.add(b);
    }
    return boxes.isEmpty ? withoutBox : boxes.length;
  }

  static double _iou(Rect a, Rect b) {
    final i = a.intersect(b);
    if (i.width <= 0 || i.height <= 0) return 0;
    final inter = i.width * i.height;
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0 : inter / union;
  }

  /// Abaikan waktu yang lewat saat kamera dijeda (aplikasi di latar belakang
  /// atau pengajar membuka layar lain) agar tidak terhitung ke status apa pun.
  void resumeAfterGap() {
    _lastUpdate = null;
    final now = _now();
    if (_stableSince != null) _stableSince = now;
    _openSegment(now);
  }

  /// Proses hasil satu frame.
  void ingest(List<Detection> detections) {
    final now = _now();
    frames++;
    final cfg = _config();

    Detection? top;
    final valid = <Detection>[];
    for (final d in detections) {
      if (d.confidence < cfg.confidenceThreshold) continue;
      if (d.direction == GazeDirection.unknown) continue;
      valid.add(d);
      if (top == null || d.confidence > top.confidence) top = d;
    }
    final candidate = top?.direction ?? GazeDirection.unknown;

    _faces = countFaces(valid);
    if (_faces >= 2) {
      _multiSince ??= now;
    } else {
      _multiSince = null;
      _multiLogged = false;
    }

    if (candidate == _pendingDir) {
      _pendingCount++;
    } else {
      _pendingDir = candidate;
      _pendingCount = 1;
      _pendingSince = now;
    }

    final needed = cfg.stabilityFrames < 1 ? 1 : cfg.stabilityFrames;
    var stableEnough = _pendingCount >= needed;
    // Wajah yang hilang sekejap (satu-dua frame meleset) jangan langsung
    // dianggap hilang; beri jeda singkat agar status tidak berkedip.
    if (candidate == GazeDirection.unknown &&
        now.difference(_pendingSince ?? now) < _minAbsentDebounce) {
      stableEnough = false;
    }

    _advance(now);

    if (stableEnough && candidate != _stableDir) {
      _stableDir = candidate;
      _stableSince = now;
      _runLogged = false;
      _confidence = 0;
      _openSegment(now);
    }

    if (top != null && top.direction == _stableDir) {
      // Haluskan angka keyakinan agar tidak melompat-lompat di layar.
      _confidence = _confidence == 0 ? top.confidence : _confidence * 0.7 + top.confidence * 0.3;
      _box = top.box;
    } else if (_stableDir == GazeDirection.unknown) {
      _confidence = 0;
      _box = null;
    }

    _checkAlerts(now, cfg);
    _publish(now);
  }

  /// Majukan waktu tanpa frame baru (dipanggil berkala oleh UI).
  void tick() {
    final now = _now();
    _advance(now);
    _checkAlerts(now, _config());
    _publish(now, force: true);
  }

  void _advance(DateTime now) {
    final last = _lastUpdate;
    _lastUpdate = now;
    if (timeline.isEmpty) _openSegment(now);
    timeline.last.end = now;
    _trimTimeline(now);
    final s = _session;
    if (last == null || s == null) return;
    final dt = now.difference(last).inMilliseconds;
    if (dt <= 0) return;
    switch (state) {
      case DetectionState.honest:
        s.focusMs += dt;
      case DetectionState.cheating:
        s.awayMs += dt;
        final held = now.difference(_stableSince ?? now).inMilliseconds;
        if (held > s.longestAwayMs) s.longestAwayMs = held;
      case DetectionState.noFace:
        s.absentMs += dt;
    }
  }

  void _openSegment(DateTime now) {
    final st = state;
    if (timeline.isNotEmpty) {
      final last = timeline.last;
      last.end = now;
      if (last.state == st) return;
    }
    timeline.add(TimelineSegment(st, now, now));
  }

  void _trimTimeline(DateTime now) {
    final cutoff = now.subtract(timelineWindow);
    while (timeline.length > 1 && timeline.first.end.isBefore(cutoff)) {
      timeline.removeAt(0);
    }
  }

  void _checkAlerts(DateTime now, EngineConfig cfg) {
    // Di luar sesi aplikasi hanya "siaga": status tampil, tanpa alarm/catatan.
    if (_session == null) return;
    _checkMultiFace(now, cfg);
    final since = _stableSince;
    if (since == null) return;
    final held = now.difference(since);
    final st = state;

    GazeDirection? dir;
    if (st == DetectionState.cheating && held >= cfg.minLookAway) {
      dir = _stableDir;
    } else if (st == DetectionState.noFace &&
        cfg.absentAlert > Duration.zero &&
        held >= cfg.absentAlert) {
      dir = GazeDirection.hilang;
    }
    if (dir == null) return;

    // Wajah hilang cukup diperingatkan sekali per rentang.
    if (dir == GazeDirection.hilang && _runLogged) return;
    final lastAlarm = _lastAlarm;
    if (lastAlarm != null && now.difference(lastAlarm) < cfg.cooldown) return;

    _lastAlarm = now;
    final isNew = !_runLogged;
    _runLogged = true;
    if (isNew) {
      final s = _session;
      if (s != null) s.incidents[dir] = (s.incidents[dir] ?? 0) + 1;
    }
    _onIncident(Incident(
      direction: dir,
      confidence: dir == GazeDirection.hilang ? 0 : _confidence,
      heldFor: held,
      time: now,
      isNewRun: isNew,
    ));
  }

  void _checkMultiFace(DateTime now, EngineConfig cfg) {
    final since = _multiSince;
    if (since == null || _multiLogged) return;
    final held = now.difference(since);
    if (held < multiFaceHold) return;
    final lastAlarm = _lastAlarm;
    if (lastAlarm != null && now.difference(lastAlarm) < cfg.cooldown) return;
    _multiLogged = true;
    _lastAlarm = now;
    final s = _session!;
    s.incidents[GazeDirection.wajahLain] = (s.incidents[GazeDirection.wajahLain] ?? 0) + 1;
    _onIncident(Incident(
      direction: GazeDirection.wajahLain,
      confidence: 0,
      heldFor: held,
      time: now,
      isNewRun: true,
    ));
  }

  bool get _alerting {
    if (_session == null) return false;
    final since = _stableSince;
    if (since == null || state != DetectionState.cheating) return false;
    return _now().difference(since) >= _config().minLookAway;
  }

  void _publish(DateTime now, {bool force = false}) {
    final prev = status.value;
    final st = state;
    final changed = prev.state != st ||
        prev.direction != _stableDir ||
        prev.alerting != _alerting ||
        prev.faces != _faces;
    final last = _lastNotify;
    if (!changed && !force && last != null && now.difference(last) < _notifyInterval) {
      return;
    }
    _lastNotify = now;
    status.value = LiveStatus(
      state: st,
      direction: _stableDir,
      confidence: _confidence,
      heldFor: now.difference(_stableSince ?? now),
      alerting: _alerting,
      box: _box,
      faces: _faces,
    );
  }

  void dispose() => status.dispose();
}
