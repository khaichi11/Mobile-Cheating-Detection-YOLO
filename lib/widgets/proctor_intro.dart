import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Pembuka CERDAS bertema kamera pengawas ujian:
/// 1. di layar gelap, "Halo!" dan "Selamat datang di CERDAS" diketik huruf demi huruf;
/// 2. empat sudut bidik bergerak dari tepi layar ke tengah dan mengunci, lalu garis pindai menyapu ke bawah
///    sehingga layar berubah terang di belakangnya;
/// 3. di dalam bidikan, ilustrasi seorang peserta menghadap depan (sudut hijau, "Fokus") dan sesekali menoleh (sudut jingga,
///    "Menoleh"), seperti yang dideteksi aplikasi. Ketuk layar di kiri atau kanan wajah: wajah menoleh ke arah itu.
/// Setelah [ready] selesai, semuanya memudar dan [onDone] dipanggil.
class ProctorIntro extends StatefulWidget {
  const ProctorIntro({super.key, required this.onDone, this.ready});

  final Future<void>? ready;
  final VoidCallback onDone;

  @override
  State<ProctorIntro> createState() => _ProctorIntroState();
}

class _ProctorIntroState extends State<ProctorIntro> with SingleTickerProviderStateMixin {
  static const _typeSec = 2.4, _scanSec = 1.8, _exitSec = .6;
  static const _minHold = 2.0, _maxHold = 10.0, _quiet = 2.5;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _h = 0, _e = 0, _x = 0, _hold = 0, _clock = 0, _poked = -10;
  double _turn = 0; // -1 menoleh kiri, 0 depan, 1 kanan; mengikuti _turnGoal pelan-pelan
  double _turnGoal = 0, _turnUntil = 0;
  bool _ready = false, _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    final ready = widget.ready;
    if (ready == null) {
      _ready = true;
    } else {
      ready.whenComplete(() => _ready = true).ignore();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    _clock += dt;
    if (_h < 1) {
      _h = math.min(1, _h + dt / _typeSec);
    } else if (_e < 1) {
      _e = math.min(1, _e + dt / _scanSec);
    } else if (!_ready || _hold < _minHold || (_clock - _poked < _quiet && _hold < _maxHold)) {
      _hold += dt;
    } else if (_x < 1) {
      _x = math.min(1, _x + dt / _exitSec);
    } else if (!_done) {
      _done = true;
      _ticker.stop();
      widget.onDone();
      return;
    }
    // wajah menoleh sendiri sesekali bila tidak sedang diketuk
    if (_clock > _turnUntil) {
      final phase = (_clock / 1.6).floor() % 4;
      _turnGoal = const [0.0, -1.0, 0.0, 1.0][phase];
    }
    _turn += (_turnGoal - _turn) * math.min(1, dt * 7);
    setState(() {});
  }

  void _tap(TapDownDetails d, Size size) {
    if (_h < 1) {
      if (_h < .75) setState(() => _h = .75);
      return;
    }
    HapticFeedback.selectionClick();
    _poked = _clock;
    _turnGoal = d.localPosition.dx < size.width / 2 ? -1 : 1;
    _turnUntil = _clock + 1.4;
  }

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final center = Offset(size.width / 2, math.min(size.height * .4, 360));
        final sweep = _h < 1 ? 0.0 : _seg(_e, .35, .85);
        final leave = Curves.easeInCubic.transform(_x);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: sweep < .5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d, size),
            child: Opacity(
              opacity: 1 - leave,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScanPainter(
                        sweep: sweep,
                        lock: _h < 1 ? 0 : Curves.easeInOutCubic.transform(_seg(_e, 0, .35)),
                        center: center,
                        turn: _turn,
                        face: Curves.easeOutCubic.transform(_seg(_e, .55, .85)),
                        blink: (_clock % 3.1) < .12,
                        clock: _clock,
                      ),
                    ),
                  ),
                  if (_h < 1) ..._typing(center),
                  if (_h == 1) _title(center),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  /// "Halo!" dan sambutan diketik satu per satu dengan kursor berkedip.
  List<Widget> _typing(Offset center) {
    const hello = 'Halo!', welcome = 'Selamat datang di CERDAS';
    final out = Curves.easeInCubic.transform(_seg(_h, .8, .97));
    final a = (hello.length * _seg(_h, .04, .3)).floor();
    final b = (welcome.length * _seg(_h, .36, .72)).floor();
    final caretOn = (_clock * 2.4).floor().isEven;
    final typingHello = a < hello.length || b == 0;
    return [
      Positioned(
        left: 24,
        right: 24,
        top: center.dy - 40,
        child: Opacity(
          opacity: 1 - out,
          child: Column(
            children: [
              Text.rich(
                TextSpan(
                  text: hello.substring(0, a),
                  children: [
                    TextSpan(
                      text: '|',
                      style: TextStyle(color: Colors.white.withValues(alpha: typingHello && caretOn ? 1 : 0)),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: welcome.substring(0, b),
                  children: [
                    TextSpan(
                      text: '|',
                      style: TextStyle(color: Colors.white.withValues(alpha: !typingHello && caretOn ? .9 : 0)),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _title(Offset center) {
    final words = Curves.easeOutCubic.transform(_seg(_e, .75, 1));
    final focused = _turn.abs() < .4;
    return Positioned(
      left: 32,
      right: 32,
      top: center.dy + 128,
      child: Opacity(
        opacity: words,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - words)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (focused ? AppColors.safe : AppColors.danger).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  focused ? 'Fokus ke depan' : 'Menoleh',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: focused ? AppColors.safe : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'CERDAS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pengawas ujian di perangkat',
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _ready ? 1 : null,
                    minHeight: 3,
                    color: AppColors.safe,
                    backgroundColor: AppColors.safe.withValues(alpha: .16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ketuk kiri atau kanan untuk menoleh',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({
    required this.sweep,
    required this.lock,
    required this.center,
    required this.turn,
    required this.face,
    required this.blink,
    required this.clock,
  });

  final double sweep, lock, turn, face, clock;
  final Offset center;
  final bool blink;

  static const _dark = [Color(0xFF2A2A26), Color(0xFF191917)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = h * sweep;
    // bagian yang belum terpindai tetap gelap
    canvas.drawRect(
      Rect.fromLTRB(0, line, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _dark,
        ).createShader(Offset.zero & size),
    );
    final focused = turn.abs() < .4;
    final accent = sweep == 0 ? Colors.white : (focused ? AppColors.safe : AppColors.danger);

    // wajah peserta di tengah bidikan
    if (face > 0) _face(canvas, face);

    // sudut bidik: dari tepi layar ke kotak di sekitar wajah
    final box = Rect.fromCenter(center: center, width: 210, height: 210);
    final far = Rect.fromLTWH(20, 60, w - 40, h - 120);
    final r = Rect.lerp(far, box, lock)!;
    final pulse = lock >= 1 && sweep >= 1 ? 1 + .03 * math.sin(clock * 4) : 1.0;
    final rr = Rect.fromCenter(center: r.center, width: r.width * pulse, height: r.height * pulse);
    final corner = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    for (final (o, dx, dy) in [
      (rr.topLeft, 1, 1),
      (rr.topRight, -1, 1),
      (rr.bottomLeft, 1, -1),
      (rr.bottomRight, -1, -1),
    ]) {
      canvas.drawLine(o, o + Offset(arm * dx, 0), corner);
      canvas.drawLine(o, o + Offset(0, arm * dy), corner);
    }

    // garis pindai dengan cahaya tipis di atasnya
    if (sweep > 0 && sweep < 1) {
      final glow = Rect.fromLTRB(0, line - 30, w, line);
      canvas.drawRect(
        glow,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.safe.withValues(alpha: 0), AppColors.safe.withValues(alpha: .35)],
          ).createShader(glow),
      );
      canvas.drawLine(
        Offset(0, line),
        Offset(w, line),
        Paint()
          ..color = AppColors.safe
          ..strokeWidth = 2.5,
      );
    }
  }

  /// Ilustrasi peserta bergaya datar: bahu berkerah, telinga, rambut pendek dengan poni menyamping, dan dua mata
  /// (tanpa hidung dan mulut). Saat menoleh, kepala sedikit menyempit, mata dan poni bergeser ke arah toleh.
  void _face(Canvas canvas, double show) {
    Paint fill(Color c) => Paint()
      ..color = c.withValues(alpha: show)
      ..isAntiAlias = true;
    canvas.save();
    canvas.translate(center.dx, center.dy + 4);
    canvas.scale(.85 + .15 * show);
    final dx = turn * 16; // pergeseran wajah ke arah toleh
    final squeeze = 1 - .1 * turn.abs();

    // bahu dan kemeja dengan kerah
    final shirt = Path()
      ..moveTo(-78, 104)
      ..lineTo(-74, 74)
      ..quadraticBezierTo(-70, 56, -44, 50)
      ..lineTo(44, 50)
      ..quadraticBezierTo(70, 56, 74, 74)
      ..lineTo(78, 104)
      ..close();
    canvas.drawPath(shirt, fill(const Color(0xFF34558B)));
    canvas.drawPath(
      Path()
        ..moveTo(-20, 50)
        ..lineTo(0, 72)
        ..lineTo(20, 50)
        ..close(),
      fill(const Color(0xFFF4F2EB)),
    );
    // leher dengan bayangan dagu
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(-13, 30, 13, 56), const Radius.circular(6)),
      fill(const Color(0xFFE2A97E)),
    );

    // telinga, lalu kepala
    final skin = fill(const Color(0xFFF0C29A));
    for (final side in const [-1.0, 1.0]) {
      final ex = side * 44 * squeeze + dx * .3;
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, 2), width: 14, height: 20), fill(const Color(0xFFE6B286)));
    }
    final head = Rect.fromCenter(center: Offset(dx * .4, -2), width: 88 * squeeze, height: 100);
    canvas.drawRRect(RRect.fromRectAndRadius(head, const Radius.circular(42)), skin);

    // rambut: tudung di atas kepala dan poni yang menyapu ke samping
    final hx = dx * .4;
    final hair = Path()
      ..moveTo(hx - 46 * squeeze, 4)
      ..cubicTo(hx - 52 * squeeze, -46, hx - 22, -66, hx + 6, -64)
      ..cubicTo(hx + 40, -62, hx + 54 * squeeze, -38, hx + 46 * squeeze, 2)
      ..cubicTo(hx + 42 * squeeze, -14, hx + 34, -24, hx + 22, -28)
      ..cubicTo(hx + 4, -16, hx - 22, -18, hx - 40 * squeeze, -14)
      ..cubicTo(hx - 42 * squeeze, -6, hx - 44 * squeeze, 0, hx - 46 * squeeze, 4)
      ..close();
    canvas.drawPath(hair, fill(const Color(0xFF2A2420)));
    // kilau rambut tipis
    canvas.drawPath(
      Path()
        ..moveTo(hx - 18, -54)
        ..quadraticBezierTo(hx + 4, -60, hx + 24, -50),
      Paint()
        ..color = Colors.white.withValues(alpha: .18 * show)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // mata: oval gelap dengan titik cahaya; berkedip sesekali
    final eyeY = 4.0, ex = dx * 1.2;
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(side * 17 * squeeze + ex, eyeY);
      if (blink) {
        canvas.drawLine(
          c - const Offset(6, 0),
          c + const Offset(6, 0),
          Paint()
            ..color = const Color(0xFF1E1E1E).withValues(alpha: show)
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: 9, height: 12), fill(const Color(0xFF1E1E1E)));
        canvas.drawCircle(c + const Offset(1.6, -2.4), 1.6, fill(Colors.white));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanPainter old) => true;
}
