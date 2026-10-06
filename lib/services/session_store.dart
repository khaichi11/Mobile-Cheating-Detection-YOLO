import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_session.dart';

/// Daftar sesi ujian yang sudah selesai, disimpan lokal sebagai JSON.
class SessionStore extends ChangeNotifier {
  static const _kKey = 'exam_sessions';
  static const int _maxSessions = 100;

  SharedPreferences? _prefs;
  final List<ExamSession> _sessions = [];

  /// Sesi terbaru di depan.
  List<ExamSession> get sessions => List.unmodifiable(_sessions.reversed);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _sessions
          ..clear()
          ..addAll(list.map((e) => ExamSession.fromJson(e as Map<String, dynamic>)));
      } catch (_) {/* abaikan data rusak */}
    }
    notifyListeners();
  }

  void add(ExamSession s) {
    _sessions.add(s);
    if (_sessions.length > _maxSessions) {
      _sessions.removeRange(0, _sessions.length - _maxSessions);
    }
    _persist();
    notifyListeners();
  }

  ExamSession? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  void clear() {
    _sessions.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    _prefs?.setString(_kKey, jsonEncode(_sessions.map((e) => e.toJson()).toList()));
  }
}
