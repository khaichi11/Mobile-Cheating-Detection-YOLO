import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/proctor_engine.dart';
import '../theme/app_theme.dart';

Color colorForState(DetectionState s) {
  switch (s) {
    case DetectionState.honest:
      return AppColors.safe;
    case DetectionState.cheating:
      return AppColors.danger;
    case DetectionState.noFace:
      return AppColors.neutral;
  }
}

/// Garis waktu status beberapa detik terakhir: hijau fokus, oranye menoleh,
/// abu-abu wajah tidak terlihat. Digambar ulang oleh [repaint] (beberapa kali
/// per detik), bukan per frame kamera.
class TimelineStrip extends StatelessWidget {
  final ProctorEngine engine;
  final Listenable repaint;
  final DateTime Function() now;

  const TimelineStrip({
    super.key,
    required this.engine,
    required this.repaint,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final secs = engine.timelineWindow.inSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: CustomPaint(
              painter: _TimelinePainter(engine, now, repaint),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('$secs dtk lalu', style: monoStyle(size: 10.5, color: AppColors.textFaint)),
            const Spacer(),
            Text('sekarang', style: monoStyle(size: 10.5, color: AppColors.textFaint)),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final ProctorEngine engine;
  final DateTime Function() now;

  _TimelinePainter(this.engine, this.now, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surfaceAlt);
    final end = now();
    final windowMs = engine.timelineWindow.inMilliseconds.toDouble();
    final start = end.subtract(engine.timelineWindow);
    final paint = Paint();
    for (final seg in engine.timeline) {
      final s = seg.start.isBefore(start) ? start : seg.start;
      final segEnd = seg == engine.timeline.last ? end : seg.end;
      if (!segEnd.isAfter(s)) continue;
      final x0 = s.difference(start).inMilliseconds / windowMs * size.width;
      final x1 = segEnd.difference(start).inMilliseconds / windowMs * size.width;
      if (x0 >= size.width) continue;
      paint.color = colorForState(seg.state).withValues(
          alpha: seg.state == DetectionState.noFace ? 0.5 : 1);
      final right = math.min(math.max(x1, x0 + 1), size.width);
      canvas.drawRect(Rect.fromLTRB(x0, 0, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => false;
}
