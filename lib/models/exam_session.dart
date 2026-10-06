import 'gaze_direction.dart';

/// Satu sesi ujian yang diawasi: nama, waktu, dan ringkasan durasi tiap status.
class ExamSession {
  final String id;
  final String name;
  final DateTime start;
  DateTime? end;

  /// Total durasi tiap status selama sesi (milidetik).
  int focusMs;
  int awayMs;
  int absentMs;

  /// Pandangan menjauh terlama tanpa jeda (milidetik).
  int longestAwayMs;

  /// Jumlah kejadian per arah selama sesi.
  final Map<GazeDirection, int> incidents;

  /// Sesi dari mode demo (wajah dummy), ditandai agar tidak tercampur.
  final bool isDemo;

  /// Durasi ujian yang direncanakan pengajar; null = tanpa batas waktu.
  final int? plannedMinutes;

  /// Lama aplikasi ditinggalkan (dipindah ke aplikasi lain) selama sesi.
  int leftAppMs;

  /// Cara sesi berakhir: 'waktu' (otomatis) atau 'pengajar' (dengan PIN).
  String? endedBy;

  ExamSession({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    this.focusMs = 0,
    this.awayMs = 0,
    this.absentMs = 0,
    this.longestAwayMs = 0,
    Map<GazeDirection, int>? incidents,
    this.isDemo = false,
    this.plannedMinutes,
    this.leftAppMs = 0,
    this.endedBy,
  }) : incidents = incidents ?? {};

  /// Waktu berakhir sesuai rencana, atau null bila tanpa batas.
  DateTime? get plannedEnd =>
      plannedMinutes == null ? null : start.add(Duration(minutes: plannedMinutes!));

  /// Sisa waktu ujian (tidak kurang dari nol), atau null bila tanpa batas.
  Duration? remaining(DateTime now) {
    final e = plannedEnd;
    if (e == null) return null;
    final r = e.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool get isActive => end == null;

  Duration get duration => (end ?? DateTime.now()).difference(start);

  int get totalIncidents => incidents.values.fold(0, (a, b) => a + b);

  /// Persentase waktu fokus terhadap waktu wajah terlihat.
  double get focusRatio {
    final seen = focusMs + awayMs;
    return seen == 0 ? 0 : focusMs / seen;
  }

  /// Arah kejadian terbanyak, atau null bila belum ada kejadian.
  GazeDirection? get topDirection {
    if (incidents.isEmpty) return null;
    return incidents.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
        'focusMs': focusMs,
        'awayMs': awayMs,
        'absentMs': absentMs,
        'longestAwayMs': longestAwayMs,
        'incidents': {for (final e in incidents.entries) e.key.rawName: e.value},
        'isDemo': isDemo,
        if (plannedMinutes != null) 'plannedMinutes': plannedMinutes,
        'leftAppMs': leftAppMs,
        if (endedBy != null) 'endedBy': endedBy,
      };

  factory ExamSession.fromJson(Map<String, dynamic> j) {
    final raw = (j['incidents'] as Map?) ?? const {};
    return ExamSession(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Sesi',
      start: DateTime.tryParse(j['start'] as String? ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(j['end'] as String? ?? ''),
      focusMs: (j['focusMs'] as num?)?.toInt() ?? 0,
      awayMs: (j['awayMs'] as num?)?.toInt() ?? 0,
      absentMs: (j['absentMs'] as num?)?.toInt() ?? 0,
      longestAwayMs: (j['longestAwayMs'] as num?)?.toInt() ?? 0,
      incidents: {
        for (final e in raw.entries)
          GazeDirectionInfo.fromClassName(e.key as String): (e.value as num).toInt(),
      },
      isDemo: j['isDemo'] as bool? ?? false,
      plannedMinutes: (j['plannedMinutes'] as num?)?.toInt(),
      leftAppMs: (j['leftAppMs'] as num?)?.toInt() ?? 0,
      endedBy: j['endedBy'] as String?,
    );
  }
}
