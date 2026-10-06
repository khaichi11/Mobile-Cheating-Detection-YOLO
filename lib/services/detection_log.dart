import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_event.dart';
import '../models/exam_session.dart';
import '../models/gaze_direction.dart';

/// Riwayat kejadian (indikasi mencontek dan wajah hilang) beserta statistik.
///
/// Disimpan persisten sebagai JSON di SharedPreferences. Statistik "hari ini"
/// dihitung sejak tengah malam; statistik total dari seluruh riwayat.
class DetectionLog extends ChangeNotifier {
  static const _kKey = 'detection_events';
  static const int _maxEvents = 1000;

  SharedPreferences? _prefs;
  final List<DetectionEvent> _events = [];

  /// Kejadian terbaru di depan.
  List<DetectionEvent> get events => List.unmodifiable(_events.reversed);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _events
          ..clear()
          ..addAll(list.map((e) => DetectionEvent.fromJson(e as Map<String, dynamic>)));
      } catch (_) {/* abaikan data rusak */}
    }
    notifyListeners();
  }

  void add(DetectionEvent e) {
    _events.add(e);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    _persist();
    notifyListeners();
  }

  void clear() {
    _events.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    _prefs?.setString(_kKey, jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  // ── Statistik ──────────────────────────────────────────────────────────────

  int get totalAll => _events.length;

  int get totalToday {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return _events.where((e) => !e.time.isBefore(midnight)).length;
  }

  /// Jumlah kejadian per arah.
  Map<GazeDirection, int> get byDirection {
    final m = <GazeDirection, int>{};
    for (final e in _events) {
      m[e.direction] = (m[e.direction] ?? 0) + 1;
    }
    return m;
  }

  DetectionEvent? get last => _events.isEmpty ? null : _events.last;

  List<DetectionEvent> forSession(String id) =>
      _events.reversed.where((e) => e.sessionId == id).toList();

  /// Ekspor riwayat sebagai teks CSV (untuk disalin/dibagikan).
  String toCsv({List<ExamSession> sessions = const []}) {
    final names = {for (final s in sessions) s.id: s.name};
    final b = StringBuffer('no,waktu,sesi,arah,confidence,durasi_detik\n');
    var i = 1;
    for (final e in _events) {
      final sesi = _csvField(names[e.sessionId] ?? '');
      b.writeln('${i++},${e.time.toIso8601String()},$sesi,${e.direction.rawName},'
          '${(e.confidence * 100).toStringAsFixed(1)}%,'
          '${(e.duration.inMilliseconds / 1000).toStringAsFixed(1)}');
    }
    return b.toString();
  }

  static String _csvField(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
