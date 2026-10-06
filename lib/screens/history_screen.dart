import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/detection_event.dart';
import '../models/exam_session.dart';
import '../models/gaze_direction.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import 'session_summary_screen.dart';

/// Riwayat: angka ringkas, lalu daftar sesi dan daftar kejadian.
class HistoryScreen extends StatefulWidget {
  final AppServices services;

  const HistoryScreen({super.key, required this.services});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final log = widget.services.log;
    final store = widget.services.sessions;
    return ListenableBuilder(
      listenable: Listenable.merge([log, store]),
      builder: (context, _) {
        final sessions = store.sessions;
        final events = log.events;
        final top = _topDirection(log.byDirection);
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Riwayat'),
              actions: [
                TextButton(
                  onPressed: events.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: log.toCsv(sessions: sessions)));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Riwayat disalin sebagai CSV')),
                          );
                        },
                  child: const Text('Salin CSV'),
                ),
                IconButton(
                  tooltip: 'Hapus riwayat',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: events.isEmpty && sessions.isEmpty ? null : _confirmClear,
                ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (_, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                    child: Column(
                      children: [
                        FigureRow([
                          Figure(
                              value: '${log.totalAll}',
                              label: 'total kejadian',
                              color: log.totalAll > 0 ? AppColors.danger : null),
                          Figure(value: '${log.totalToday}', label: 'hari ini'),
                        ]),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 14),
                        FigureRow([
                          Figure(value: '${sessions.length}', label: 'sesi ujian'),
                          Figure(
                            value: top == null ? '-' : top.$1.shortLabel,
                            label: 'kejadian tersering',
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: TabBar(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: [
                      Tab(text: 'Sesi (${sessions.length})'),
                      Tab(text: 'Kejadian (${events.length})'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _sessionList(sessions),
                  _eventList(events, sessions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  (GazeDirection, int)? _topDirection(Map<GazeDirection, int> m) {
    if (m.isEmpty) return null;
    final e = m.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (e.key, e.value);
  }

  Widget _sessionList(List<ExamSession> sessions) {
    if (sessions.isEmpty) {
      return const _Empty(
        'Belum ada sesi. Pengajar memulai sesi dari layar kamera dengan PIN; '
        'durasi fokus dan kejadian tiap sesi tercatat di sini.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      children: [
        for (final s in sessions)
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SessionSummaryScreen(services: widget.services, session: s),
            )),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(size: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDate(s.start)} · ${formatTime(s.start)} · '
                          '${formatDurationShort(s.duration)}${s.isDemo ? ' · demo' : ''}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.focusMs + s.awayMs == 0
                              ? 'fokus --'
                              : 'fokus ${formatPercent(s.focusRatio)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${s.totalIncidents}',
                          style: displayStyle(
                              size: 24,
                              color: s.totalIncidents > 0 ? AppColors.danger : AppColors.safe)),
                      const Text('kejadian',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _eventList(List<DetectionEvent> events, List<ExamSession> sessions) {
    if (events.isEmpty) return const _Empty('Belum ada kejadian tercatat.');
    final names = {for (final s in sessions) s.id: s.name};
    final children = <Widget>[];
    String? day;
    for (final e in events.take(300)) {
      final d = formatDate(e.time);
      if (d != day) {
        day = d;
        children.add(Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 8 : 22, bottom: 2),
          child: Text(d, style: displayStyle(size: 14.5, color: AppColors.textSecondary)),
        ));
      }
      children.add(EventTile(event: e, sessionName: names[e.sessionId]));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 28), children: children);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text('Semua kejadian dan ringkasan sesi akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.services.log.clear();
      widget.services.sessions.clear();
    }
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.55)),
    );
  }
}
