/// Format waktu dan angka dalam gaya Indonesia (tanpa paket intl).
library;

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 07:05 atau 1:07:05.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// "1 j 5 mnt", "12 mnt", "45 dtk".
String formatDurationShort(Duration d) {
  if (d.inHours > 0) return '${d.inHours} j ${d.inMinutes.remainder(60)} mnt';
  if (d.inMinutes > 0) return '${d.inMinutes} mnt';
  return '${d.inSeconds} dtk';
}

/// "1,8 dtk".
String formatSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} dtk';

/// "6 Okt 2026".
String formatDate(DateTime t) => '${t.day} ${_bulan[t.month - 1]} ${t.year}';

/// "14:05".
String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// "14:05:09".
String formatTimeSec(DateTime t) => '${formatTime(t)}:${_two(t.second)}';

/// "87%".
String formatPercent(double v) => '${(v * 100).round()}%';

/// Nama sesi bawaan: "Ujian 6 Okt, 14:05".
String defaultSessionName(DateTime t) =>
    'Ujian ${t.day} ${_bulan[t.month - 1]}, ${formatTime(t)}';
