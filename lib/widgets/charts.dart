import 'package:flutter/material.dart';

import '../models/gaze_direction.dart';
import '../theme/app_theme.dart';

/// Batang bertumpuk proporsi waktu: fokus, menoleh, dan wajah tidak terlihat.
class FocusBar extends StatelessWidget {
  final int focusMs;
  final int awayMs;
  final int absentMs;

  const FocusBar({
    super.key,
    required this.focusMs,
    required this.awayMs,
    required this.absentMs,
  });

  @override
  Widget build(BuildContext context) {
    final parts = [
      (focusMs, AppColors.safe),
      (awayMs, AppColors.danger),
      (absentMs, AppColors.neutral),
    ].where((p) => p.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 10,
        child: parts.isEmpty
            ? const ColoredBox(color: AppColors.surfaceAlt)
            : Row(
                children: [
                  for (final p in parts)
                    Expanded(flex: p.$1, child: ColoredBox(color: p.$2)),
                ],
              ),
      ),
    );
  }
}

/// Keterangan warna kecil (kotak + teks).
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// Judul bagian: teks biasa dengan garis tipis di bawahnya, seperti lembar ujian.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(text, style: displayStyle(size: 15.5))),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.lineStrong),
        ],
      ),
    );
  }
}

/// Satu angka besar dengan label di bawahnya.
class Figure extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const Figure({super.key, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: displayStyle(size: 26, color: color ?? AppColors.textPrimary)),
        ),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.3)),
      ],
    );
  }
}

/// Deretan angka dipisah garis vertikal tipis.
class FigureRow extends StatelessWidget {
  final List<Figure> figures;

  const FigureRow(this.figures, {super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < figures.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: VerticalDivider(width: 1, color: AppColors.line),
              ),
            Expanded(child: figures[i]),
          ],
        ],
      ),
    );
  }
}

/// Tabel jumlah kejadian per jenis.
class IncidentTable extends StatelessWidget {
  final Map<GazeDirection, int> counts;

  const IncidentTable({super.key, required this.counts});

  static const order = [
    GazeDirection.kiri,
    GazeDirection.kanan,
    GazeDirection.bawah,
    GazeDirection.atas,
    GazeDirection.hilang,
    GazeDirection.wajahLain,
    GazeDirection.keluarAplikasi,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in order) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(d.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: (counts[d] ?? 0) > 0 ? AppColors.textPrimary : AppColors.textFaint,
                      )),
                ),
                Text('${counts[d] ?? 0}',
                    style: monoStyle(
                      size: 15,
                      weight: FontWeight.w600,
                      color: (counts[d] ?? 0) > 0 ? AppColors.danger : AppColors.textFaint,
                    )),
              ],
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }
}
