import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/teacher_gate.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';

/// Pengaturan: aturan deteksi, sesi, peringatan, kamera, dan PIN.
///
/// Hanya bisa dibuka setelah PIN pengajar dimasukkan (lihat [TeacherGate]).
class SettingsScreen extends StatelessWidget {
  final AppServices services;

  const SettingsScreen({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        actions: [
          TextButton(
            onPressed: () {
              settings.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan dikembalikan ke bawaan')),
              );
            },
            child: const Text('Bawaan'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
          children: [
            const SectionLabel('Aturan deteksi'),
            _SliderRow(
              title: 'Ambang keyakinan',
              subtitle: 'Deteksi di bawah angka ini diabaikan.',
              value: settings.confidenceThreshold,
              min: 0.3,
              max: 0.95,
              divisions: 13,
              display: formatPercent(settings.confidenceThreshold),
              onChanged: settings.setConfidence,
            ),
            _SliderRow(
              title: 'Frame stabil',
              subtitle: 'Frame berturut-turut sebelum status berganti.',
              value: settings.stabilityFrames.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              display: '${settings.stabilityFrames} frame',
              onChanged: (v) => settings.setStability(v.round()),
            ),
            _SliderRow(
              title: 'Lama menoleh minimum',
              subtitle: 'Menoleh lebih singkat dari ini tidak dicatat.',
              value: settings.minLookAwayMs.toDouble(),
              min: 0,
              max: 3000,
              divisions: 12,
              display: settings.minLookAwayMs == 0
                  ? 'langsung'
                  : formatSeconds(Duration(milliseconds: settings.minLookAwayMs)),
              onChanged: (v) => settings.setMinLookAway(v.round()),
            ),
            _SliderRow(
              title: 'Wajah tidak terlihat',
              subtitle: 'Selama sesi, dicatat bila wajah hilang selama ini.',
              value: settings.absentAlertSec.toDouble(),
              min: 0,
              max: 30,
              divisions: 6,
              display: settings.absentAlertSec == 0 ? 'mati' : '${settings.absentAlertSec} dtk',
              onChanged: (v) => settings.setAbsentAlert(v.round()),
            ),
            const SectionLabel('Sesi ujian'),
            _SliderRow(
              title: 'Durasi bawaan',
              subtitle: 'Diusulkan saat memulai sesi. Sesi berakhir otomatis saat waktu habis.',
              value: settings.sessionMinutes.toDouble(),
              min: 0,
              max: 180,
              divisions: 12,
              display: settings.sessionMinutes == 0 ? 'tanpa batas' : '${settings.sessionMinutes} mnt',
              onChanged: (v) => settings.setSessionMinutes(v.round()),
            ),
            const SectionLabel('Peringatan'),
            _SwitchRow(
              title: 'Suara alarm',
              subtitle: 'Bunyikan alarm saat ada kejadian.',
              value: settings.soundEnabled,
              onChanged: settings.setSound,
            ),
            _SwitchRow(
              title: 'Getar',
              subtitle: 'Getarkan perangkat saat ada kejadian.',
              value: settings.vibrationEnabled,
              onChanged: settings.setVibration,
            ),
            _SliderRow(
              title: 'Jeda antar peringatan',
              subtitle: 'Agar alarm tidak berbunyi terus-menerus.',
              value: settings.alertCooldownSec.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              display: '${settings.alertCooldownSec} dtk',
              onChanged: (v) => settings.setCooldown(v.round()),
            ),
            _SwitchRow(
              title: 'Catat riwayat',
              subtitle: 'Simpan setiap kejadian ke Riwayat.',
              value: settings.logEvents,
              onChanged: settings.setLogEvents,
            ),
            const SectionLabel('Kamera dan layar'),
            _SwitchRow(
              title: 'Mulai dengan kamera depan',
              subtitle: 'Berlaku saat aplikasi dibuka berikutnya.',
              value: settings.defaultFrontCamera,
              onChanged: settings.setDefaultFrontCamera,
            ),
            _SwitchRow(
              title: 'Layar tetap menyala',
              subtitle: 'Cegah layar tidur selama pemantauan.',
              value: settings.keepScreenAwake,
              onChanged: settings.setKeepScreenAwake,
            ),
            const SectionLabel('Keamanan'),
            InkWell(
              onTap: () => TeacherGate.changePin(context, services),
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
                          const Text('PIN pengajar',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            settings.hasTeacherPin
                                ? 'Ketuk untuk mengganti PIN.'
                                : 'Belum diatur. Ketuk untuk membuat.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(display, style: monoStyle(size: 15, weight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
