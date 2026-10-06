import 'package:flutter/material.dart';

import '../models/gaze_direction.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';

/// Informasi aplikasi: cara kerja, aturan sesi, privasi, dan kredit.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 36),
        children: [
          Row(
            children: [
              Image.asset('assets/brand/logo.png', width: 52, height: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CERDAS', style: displayStyle(size: 24, weight: FontWeight.w700)),
                    const Text('Versi 2.0.0',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Cheating Examination Recognition & Detection · YOLO-based',
              style: TextStyle(fontSize: 14.5, height: 1.4)),
          const SectionLabel('Cara kerja'),
          const _Paragraph(
            'Model YOLOv12n (LiteRT, masukan 320 piksel) berjalan langsung di perangkat dan '
            'membaca arah kepala dari kamera depan. Hasil tiap frame distabilkan dulu: status '
            'baru berganti setelah beberapa frame berturut-turut sepakat. Menoleh lebih lama '
            'dari batas di Pengaturan dicatat sebagai kejadian dan memicu alarm.',
          ),
          const SectionLabel('Aturan sesi'),
          const _Rule('Di luar sesi aplikasi dalam mode siaga: status tampil, tanpa alarm dan tanpa catatan.'),
          const _Rule('Memulai dan mengakhiri sesi hanya bisa dengan PIN pengajar.'),
          const _Rule('Sesi berakhir otomatis saat durasi ujian habis.'),
          const _Rule('Selama sesi, tombol kembali dikunci; ganti kamera dan pengaturan butuh PIN.'),
          const _Rule('Meninggalkan aplikasi, wajah tidak terlihat, dan adanya wajah lain ikut dicatat.'),
          const _Rule('Akses pengajar terkunci lagi 60 detik setelah PIN dimasukkan.'),
          const SectionLabel('Kelas yang dikenali'),
          for (final d in GazeDirectionInfo.modelClasses)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(child: Text(d.label, style: const TextStyle(fontSize: 14.5))),
                  Text(d.isCheating ? 'indikasi' : 'fokus',
                      style: TextStyle(color: d.color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SectionLabel('Batasan'),
          const _Paragraph(
            'Arah kepala bukan bukti mencontek. Gunakan hasilnya sebagai penanda untuk ditinjau '
            'pengawas. Pencahayaan, sudut kamera, dan kacamata dapat memengaruhi akurasi.',
          ),
          const SectionLabel('Privasi'),
          const _Paragraph(
            'Gambar kamera diproses di perangkat dan tidak disimpan maupun dikirim. Yang '
            'disimpan hanya jenis kejadian, keyakinan, waktu, dan lamanya. Beri tahu peserta '
            'bahwa ujian dipantau kamera sebelum sesi dimulai.',
          ),
          const SectionLabel('Kredit dan lisensi'),
          const _Paragraph(
            'Model dilatih oleh Khairuramdhani dan Naufal Arya Pradipta dengan Ultralytics '
            'YOLOv12n. Aplikasi memakai plugin ultralytics_yolo dan dirilis dengan lisensi '
            'AGPL-3.0. Foto wajah pada mode demo adalah orang fiktif buatan AI (Google Gemini), '
            'diperbesar dengan Real-ESRGAN, bukan foto orang nyata. Huruf Poppins dan Inter '
            '(SIL Open Font License).',
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: const TextStyle(height: 1.6, fontSize: 14.5)),
      );
}

class _Rule extends StatelessWidget {
  final String text;

  const _Rule(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 10),
              child: SizedBox(width: 6, height: 1.5, child: ColoredBox(color: AppColors.textPrimary)),
            ),
            Expanded(child: Text(text, style: const TextStyle(height: 1.5, fontSize: 14.5))),
          ],
        ),
      );
}
