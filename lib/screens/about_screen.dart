import 'package:flutter/material.dart';

import '../models/gaze_direction.dart';
import '../theme/app_theme.dart';

/// Layar "Tentang": penjelasan cara kerja, daftar kelas, dan kredit.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const Icon(Icons.visibility, size: 64, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text('Deteksi Mencontek',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Versi 1.0.0',
                    style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.9))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _card(
            icon: Icons.lightbulb_outline,
            title: 'Cara kerja',
            child: const Text(
              'Aplikasi memakai model YOLO (TensorFlow Lite) yang berjalan langsung '
              'di perangkat untuk mengenali arah pandang kepala dari kamera secara '
              'real-time. Saat pandangan menjauh dari layar (atas, bawah, kiri, '
              'kanan) secara stabil, aplikasi menandainya sebagai indikasi mencontek '
              'dan memicu peringatan. Semua proses berjalan luring (offline) — '
              'tidak ada gambar yang dikirim ke server.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.category,
            title: 'Kelas yang dikenali',
            child: Column(
              children: GazeDirection.values
                  .where((d) => d != GazeDirection.unknown)
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(d.icon, color: d.color, size: 20),
                            const SizedBox(width: 12),
                            Text(d.label,
                                style: const TextStyle(color: AppColors.textPrimary)),
                            const Spacer(),
                            Text(d.isCheating ? 'Mencontek' : 'Jujur',
                                style: TextStyle(
                                    color: d.color, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.privacy_tip_outlined,
            title: 'Privasi',
            child: const Text(
              'Pemrosesan gambar dilakukan sepenuhnya di perangkat. Riwayat kejadian '
              'disimpan lokal dan dapat dihapus kapan saja dari layar Riwayat.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.groups,
            title: 'Kredit',
            child: const Text(
              'Model dilatih oleh Khairuramdhani dan Naufal Arya Pradipta '
              '(YOLOv12n). Dibangun dengan Flutter + ultralytics_yolo.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
