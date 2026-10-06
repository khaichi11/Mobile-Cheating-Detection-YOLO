import 'package:flutter/material.dart';

/// Oval panduan posisi wajah di tengah layar kamera, seperti versi awal
/// aplikasi. Warnanya mengikuti status: putih saat wajah belum terlihat,
/// hijau saat fokus, oranye saat menoleh. Hanya garis tipis sehingga wajah
/// tetap terlihat jelas.
class FaceGuide extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const FaceGuide({
    super.key,
    required this.color,
    this.width = 250,
    this.height = 330,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 220),
        builder: (_, c, _) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: c ?? color, width: 3),
            borderRadius: BorderRadius.all(Radius.elliptical(width / 2, height / 2)),
          ),
        ),
      ),
    );
  }
}
