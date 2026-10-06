import 'package:flutter/material.dart';

import '../logic/proctor_engine.dart';
import '../models/gaze_direction.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'timeline_strip.dart';

/// Baris status utama di panel bawah layar kamera: judul status besar,
/// keyakinan di kanan, dan satu baris keterangan. Tanpa ikon hias.
class StatusRow extends StatelessWidget {
  final LiveStatus status;
  final bool inSession;

  const StatusRow({super.key, required this.status, required this.inSession});

  @override
  Widget build(BuildContext context) {
    final st = status.state;
    final title = switch (st) {
      DetectionState.noFace => 'Wajah belum terlihat',
      _ => status.direction.label,
    };
    final String note;
    if (!inSession) {
      note = 'Mode siaga · belum ada alarm atau catatan';
    } else if (status.faces >= 2) {
      note = 'Terlihat ${status.faces} wajah di kamera';
    } else {
      note = switch (st) {
        DetectionState.noFace => 'Posisikan wajah peserta di tengah kamera',
        DetectionState.honest => 'Fokus · ${formatSeconds(status.heldFor)}',
        DetectionState.cheating => status.alerting
            ? 'Indikasi tercatat · menoleh ${formatSeconds(status.heldFor)}'
            : 'Menoleh ${formatSeconds(status.heldFor)}',
      };
    }
    final noteColor = inSession && (status.alerting || status.faces >= 2)
        ? AppColors.danger
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(size: 21, color: colorForState(st))),
            ),
            if (st != DetectionState.noFace)
              Text(formatPercent(status.confidence),
                  style: monoStyle(size: 18, weight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 3),
        Text(note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: noteColor, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Satu pasangan label dan nilai untuk deretan angka di panel kamera.
class InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InlineStat({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: monoStyle(
                    size: 17, weight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Deretan [InlineStat] dipisah garis vertikal tipis.
class InlineStats extends StatelessWidget {
  final List<InlineStat> stats;

  const InlineStats(this.stats, {super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: VerticalDivider(width: 1, color: AppColors.line),
              ),
            stats[i],
          ],
        ],
      ),
    );
  }
}
