import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/teacher_gate.dart';
import '../theme/app_theme.dart';

/// Layar pengaturan: ambang deteksi, suara, getar, kamera, PIN, dll.
///
/// Hanya bisa diakses setelah pengajar membuka kunci (lihat [TeacherGate]).
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
          IconButton(
            tooltip: 'Kembalikan default',
            icon: const Icon(Icons.restart_alt),
            onPressed: settings.resetToDefaults,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _sectionTitle('Deteksi'),
            _sliderTile(
              icon: Icons.speed,
              title: 'Ambang keyakinan',
              subtitle: 'Minimal confidence agar deteksi dihitung',
              value: settings.confidenceThreshold,
              min: 0.3,
              max: 0.95,
              divisions: 13,
              display: '${(settings.confidenceThreshold * 100).toStringAsFixed(0)}%',
              onChanged: settings.setConfidence,
            ),
            _sliderTile(
              icon: Icons.layers,
              title: 'Frame stabil',
              subtitle: 'Jumlah frame berturut sebelum status berubah',
              value: settings.stabilityFrames.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              display: '${settings.stabilityFrames} frame',
              onChanged: (v) => settings.setStability(v.round()),
            ),
            _sliderTile(
              icon: Icons.hourglass_bottom,
              title: 'Jeda antar peringatan',
              subtitle: 'Cooldown agar alarm tak berbunyi terus',
              value: settings.alertCooldownSec.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              display: '${settings.alertCooldownSec} detik',
              onChanged: (v) => settings.setCooldown(v.round()),
            ),
            const Divider(),
            _sectionTitle('Peringatan'),
            _switchTile(
              icon: Icons.volume_up,
              title: 'Suara alarm',
              subtitle: 'Bunyikan alarm saat terdeteksi mencontek',
              value: settings.soundEnabled,
              onChanged: settings.setSound,
            ),
            _switchTile(
              icon: Icons.vibration,
              title: 'Getar',
              subtitle: 'Getarkan perangkat saat terdeteksi',
              value: settings.vibrationEnabled,
              onChanged: settings.setVibration,
            ),
            _switchTile(
              icon: Icons.fact_check,
              title: 'Catat riwayat',
              subtitle: 'Simpan setiap kejadian ke Riwayat',
              value: settings.logEvents,
              onChanged: settings.setLogEvents,
            ),
            const Divider(),
            _sectionTitle('Kamera & Layar'),
            _switchTile(
              icon: Icons.camera_front,
              title: 'Mulai dengan kamera depan',
              subtitle: 'Default kamera saat aplikasi dibuka',
              value: settings.defaultFrontCamera,
              onChanged: settings.setDefaultFrontCamera,
            ),
            _switchTile(
              icon: Icons.screen_lock_portrait,
              title: 'Layar tetap menyala',
              subtitle: 'Cegah layar tidur selama pemantauan',
              value: settings.keepScreenAwake,
              onChanged: settings.setKeepScreenAwake,
            ),
            const Divider(),
            _sectionTitle('Keamanan'),
            ListTile(
              leading: const Icon(Icons.password, color: AppColors.textSecondary),
              title: const Text('PIN Pengajar',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text(
                settings.hasTeacherPin
                    ? 'Tap untuk mengganti PIN'
                    : 'Belum diatur — tap untuk membuat',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () => TeacherGate.changePin(context, services),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _sliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textPrimary)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(display,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
