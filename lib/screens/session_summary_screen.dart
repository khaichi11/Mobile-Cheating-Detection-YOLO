import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/detection_event.dart';
import '../models/exam_session.dart';
import '../models/gaze_direction.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';

/// Ringkasan satu sesi ujian, ditata seperti lembar hasil: angka utama,
/// proporsi waktu, tabel kejadian, lalu daftar kejadian.
class SessionSummaryScreen extends StatelessWidget {
  final AppServices services;
  final ExamSession session;

  const SessionSummaryScreen({super.key, required this.services, required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final events = services.log.forSession(s.id);
    final end = s.end ?? DateTime.now();
    final seen = s.focusMs + s.awayMs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan sesi'),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _csv(events)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kejadian sesi disalin sebagai CSV')),
              );
            },
            child: const Text('Salin CSV'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 36),
        children: [
          Text(s.name, style: displayStyle(size: 24)),
          const SizedBox(height: 4),
          Text(
            '${formatDate(s.start)} · ${formatTime(s.start)}–${formatTime(end)} · '
            '${formatDurationShort(end.difference(s.start))}'
            '${s.isDemo ? ' · demo' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          Text(_endedText(s), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(seen == 0 ? '--' : '${(s.focusRatio * 100).round()}%',
                  style: displayStyle(size: 52, weight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('waktu fokus ke depan\ndari waktu wajah terlihat',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.35)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FocusBar(focusMs: s.focusMs, awayMs: s.awayMs, absentMs: s.absentMs),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              LegendDot(color: AppColors.safe, label: 'Fokus ${_clock(s.focusMs)}'),
              LegendDot(color: AppColors.danger, label: 'Menoleh ${_clock(s.awayMs)}'),
              LegendDot(color: AppColors.neutral, label: 'Tidak terlihat ${_clock(s.absentMs)}'),
            ],
          ),
          const SizedBox(height: 26),
          FigureRow([
            Figure(
              value: '${s.totalIncidents}',
              label: 'kejadian',
              color: s.totalIncidents > 0 ? AppColors.danger : AppColors.safe,
            ),
            Figure(
              value: formatSeconds(Duration(milliseconds: s.longestAwayMs)),
              label: 'menoleh terlama',
            ),
            Figure(
              value: formatSeconds(Duration(milliseconds: s.leftAppMs)),
              label: 'aplikasi ditinggalkan',
            ),
          ]),
          const SizedBox(height: 22),
          Text(_verdict(s), style: const TextStyle(height: 1.55, fontSize: 14.5)),
          const SectionLabel('Kejadian per jenis'),
          IncidentTable(counts: s.incidents),
          SectionLabel('Daftar kejadian', trailing: Text('${events.length}', style: monoStyle())),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Tidak ada kejadian tercatat di sesi ini.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            for (final e in events) EventTile(event: e),
        ],
      ),
    );
  }

  static String _clock(int ms) => formatClock(Duration(milliseconds: ms));

  static String _endedText(ExamSession s) {
    final planned = s.plannedMinutes == null ? 'tanpa batas waktu' : 'rencana ${s.plannedMinutes} menit';
    return switch (s.endedBy) {
      'waktu' => 'Berakhir otomatis saat waktu habis ($planned)',
      'pengajar' => 'Diakhiri pengajar dengan PIN ($planned)',
      _ => 'Sesi ($planned)',
    };
  }

  static String _verdict(ExamSession s) {
    if (s.focusMs + s.awayMs == 0) {
      return 'Wajah belum terdeteksi selama sesi, jadi belum ada data fokus.';
    }
    final pct = (s.focusRatio * 100).round();
    if (s.totalIncidents == 0) {
      return 'Peserta fokus ke depan $pct% dari waktu wajahnya terlihat, '
          'tanpa kejadian yang memicu peringatan.';
    }
    final top = s.topDirection;
    return 'Peserta fokus ke depan $pct% dari waktu wajahnya terlihat dan tercatat '
        '${s.totalIncidents} kejadian'
        '${top == null ? '' : ', paling sering "${top.shortLabel.toLowerCase()}"'}. '
        'Ini indikasi, bukan bukti; tinjau bersama pengawas ujian.';
  }

  static String _csv(List<DetectionEvent> events) {
    final b = StringBuffer('waktu,kejadian,confidence,durasi_detik\n');
    for (final e in events.reversed) {
      b.writeln('${e.time.toIso8601String()},${e.direction.rawName},'
          '${(e.confidence * 100).toStringAsFixed(1)}%,'
          '${(e.duration.inMilliseconds / 1000).toStringAsFixed(1)}');
    }
    return b.toString();
  }
}

/// Satu baris kejadian: jam, jenis, lama, keyakinan. Dipisah garis tipis.
class EventTile extends StatelessWidget {
  final DetectionEvent event;
  final String? sessionName;

  const EventTile({super.key, required this.event, this.sessionName});

  @override
  Widget build(BuildContext context) {
    final d = event.direction;
    final meta = <String>[
      if (event.duration > Duration.zero) formatSeconds(event.duration),
      ?sessionName,
    ];
    final hasConfidence = d.isCheating;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(formatTimeSec(event.time),
                style: monoStyle(size: 13.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty)
                  Text(meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (hasConfidence)
            Text(formatPercent(event.confidence), style: monoStyle(size: 13.5)),
        ],
      ),
    );
  }
}
