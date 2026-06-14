import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_event.dart';
import '../models/gaze_direction.dart';

/// Riwayat kejadian terdeteksi mencontek + statistik.
///
/// Disimpan persisten sebagai JSON di SharedPreferences. Statistik
/// "sesi" dihitung dari kejadian sejak aplikasi dibuka; statistik total
/// dihitung dari seluruh riwayat.
class DetectionLog extends ChangeNotifier {
  static const _kKey = 'detection_events';
  static const int _maxEvents = 500;

  SharedPreferences? _prefs;
  final List<DetectionEvent> _events = [];
  final DateTime sessionStart = DateTime.now();

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

  int get totalSession =>
      _events.where((e) => e.time.isAfter(sessionStart)).length;

  /// Jumlah per arah (hanya arah mencontek).
  Map<GazeDirection, int> get byDirection {
    final m = <GazeDirection, int>{};
    for (final e in _events) {
      m[e.direction] = (m[e.direction] ?? 0) + 1;
    }
    return m;
  }

  DetectionEvent? get last => _events.isEmpty ? null : _events.last;

  Duration get sessionDuration => DateTime.now().difference(sessionStart);

  /// Ekspor riwayat sebagai teks CSV (untuk dibagikan/disalin).
  String toCsv() {
    final b = StringBuffer('no,waktu,arah,confidence\n');
    var i = 1;
    for (final e in _events) {
      b.writeln('${i++},${e.time.toIso8601String()},${e.direction.rawName},'
          '${(e.confidence * 100).toStringAsFixed(1)}%');
    }
    return b.toString();
  }
}
