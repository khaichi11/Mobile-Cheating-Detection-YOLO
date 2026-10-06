import 'package:flutter/material.dart';

import '../screens/about_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../services/app_services.dart';
import '../services/teacher_gate.dart';
import '../theme/app_theme.dart';

/// Menu navigasi (drawer).
///
/// Riwayat dan Pengaturan dikunci PIN pengajar. Selama sesi berjalan, mode
/// demo tidak bisa dibuka agar peserta tidak bisa mengalihkan kamera.
class AppDrawer extends StatefulWidget {
  final AppServices services;
  final bool demoMode;
  final bool sessionActive;

  /// Membuka layar lain; layar kamera menjeda deteksi selama layar itu terbuka.
  final Future<void> Function(Widget page) onOpenPage;
  final VoidCallback onToggleDemo;

  const AppDrawer({
    super.key,
    required this.services,
    required this.demoMode,
    required this.sessionActive,
    required this.onOpenPage,
    required this.onToggleDemo,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  AppServices get services => widget.services;

  Future<void> _openGated(Widget page) async {
    final ok = await TeacherGate.ensureAccess(context, services);
    if (!ok || !mounted) return;
    Navigator.pop(context); // tutup drawer
    await widget.onOpenPage(page);
  }

  Future<void> _open(Widget page) async {
    Navigator.pop(context);
    await widget.onOpenPage(page);
  }

  void _toggleDemo() {
    Navigator.pop(context);
    if (widget.sessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akhiri sesi dulu sebelum pindah mode')),
      );
      return;
    }
    widget.onToggleDemo();
  }

  void _lock() {
    setState(services.lockTeacher);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akses pengajar dikunci')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = services.teacherUnlocked;
    return Drawer(
      width: 300,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          children: [
            Row(
              children: [
                Image.asset('assets/brand/logo.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Text('CERDAS', style: displayStyle(size: 22, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Cheating Examination Recognition & Detection · YOLO-based',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            Text(
              unlocked ? 'Akses pengajar terbuka' : 'Akses pengajar terkunci',
              style: TextStyle(
                color: unlocked ? AppColors.safe : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.lineStrong),
            _item(
              title: widget.demoMode ? 'Kembali ke kamera' : 'Kamera',
              subtitle: widget.demoMode ? 'Keluar dari mode demo' : 'Pemantauan langsung',
              selected: !widget.demoMode,
              onTap: widget.demoMode ? _toggleDemo : () => Navigator.pop(context),
            ),
            _item(
              title: 'Mode demo',
              subtitle: 'Wajah dummy, tanpa kamera',
              selected: widget.demoMode,
              enabled: !widget.sessionActive,
              onTap: widget.demoMode ? () => Navigator.pop(context) : _toggleDemo,
            ),
            _item(
              title: 'Riwayat',
              subtitle: 'Sesi, kejadian, ekspor CSV',
              locked: !unlocked,
              onTap: () => _openGated(HistoryScreen(services: services)),
            ),
            _item(
              title: 'Pengaturan',
              subtitle: 'Aturan deteksi, alarm, PIN',
              locked: !unlocked,
              onTap: () => _openGated(SettingsScreen(services: services)),
            ),
            _item(
              title: 'Tentang',
              subtitle: 'Cara kerja, privasi, kredit',
              onTap: () => _open(const AboutScreen()),
            ),
            if (unlocked)
              _item(
                title: 'Kunci akses pengajar',
                subtitle: 'Terkunci otomatis setelah 60 detik',
                onTap: _lock,
              ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool selected = false,
    bool locked = false,
    bool enabled = true,
  }) {
    final fg = enabled ? AppColors.textPrimary : AppColors.textFaint;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              margin: const EdgeInsets.only(right: 12),
              color: selected ? AppColors.textPrimary : Colors.transparent,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: fg)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            if (locked)
              const Text('PIN',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
