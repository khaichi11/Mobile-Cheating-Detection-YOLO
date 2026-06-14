import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gaze_direction.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

/// Riwayat kejadian terdeteksi mencontek + ringkasan statistik.
class HistoryScreen extends StatelessWidget {
  final AppServices services;

  const HistoryScreen({super.key, required this.services});

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

  String _fmtDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    if (h > 0) return '${h}j ${m}m';
    if (m > 0) return '${m}m ${s}d';
    return '${s}d';
  }

  @override
  Widget build(BuildContext context) {
    final log = services.log;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat & Statistik'),
        actions: [
          IconButton(
            tooltip: 'Salin CSV',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              if (log.totalAll == 0) return;
              Clipboard.setData(ClipboardData(text: log.toCsv()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Riwayat disalin sebagai CSV')),
              );
            },
          ),
          IconButton(
            tooltip: 'Hapus riwayat',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final byDir = log.byDirection;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    icon: Icons.warning_amber,
                    label: 'Peringatan sesi ini',
                    value: '${log.totalSession}',
                    color: AppColors.danger,
                  ),
                  StatCard(
                    icon: Icons.summarize,
                    label: 'Total tercatat',
                    value: '${log.totalAll}',
                    color: AppColors.primary,
                  ),
                  StatCard(
                    icon: Icons.timer_outlined,
                    label: 'Durasi sesi',
                    value: _fmtDuration(log.sessionDuration),
                    color: AppColors.safe,
                  ),
                  StatCard(
                    icon: Icons.schedule,
                    label: 'Terakhir',
                    value: log.last == null ? '-' : _fmtTime(log.last!.time),
                    color: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (byDir.isNotEmpty) ...[
                const Text('Rincian per arah',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...byDir.entries.map((e) => _directionBar(e.key, e.value, log.totalAll)),
                const SizedBox(height: 20),
              ],
              const Text('Daftar kejadian',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (log.events.isEmpty)
                _emptyState()
              else
                ...log.events.map((e) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: e.direction.color.withValues(alpha: 0.2),
                          child: Icon(e.direction.icon, color: e.direction.color),
                        ),
                        title: Text(e.direction.label,
                            style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text('${_fmtDate(e.time)} · ${_fmtTime(e.time)}',
                            style: const TextStyle(color: AppColors.textSecondary)),
                        trailing: Text('${(e.confidence * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: AppColors.forConfidence(e.confidence),
                                fontWeight: FontWeight.bold)),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _directionBar(GazeDirection dir, int count, int total) {
    final frac = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(dir.icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(dir.label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.danger),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptyState() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Belum ada kejadian tercatat',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text('Semua kejadian yang tercatat akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              services.log.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
