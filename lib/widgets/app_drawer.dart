import 'package:flutter/material.dart';

import '../screens/about_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../services/app_services.dart';
import '../services/teacher_gate.dart';
import '../theme/app_theme.dart';

/// Menu navigasi (drawer) untuk berpindah antar fitur aplikasi.
///
/// Riwayat dan Pengaturan dikunci di balik PIN pengajar agar peserta ujian
/// tidak bisa memanipulasi data atau mematikan deteksi.
class AppDrawer extends StatefulWidget {
  final AppServices services;

  const AppDrawer({super.key, required this.services});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  AppServices get services => widget.services;

  Future<void> _openGated(Widget page) async {
    final ok = await TeacherGate.ensureAccess(context, services);
    if (!ok || !mounted) return;
    Navigator.pop(context); // tutup drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _open(Widget page) {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _lock() {
    setState(() => services.teacherUnlocked = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mode pengajar dikunci')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = services.teacherUnlocked;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(unlocked),
          ListTile(
            leading: const Icon(Icons.center_focus_strong, color: AppColors.primary),
            title: const Text('Deteksi'),
            subtitle: const Text('Kamera langsung'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Riwayat & Statistik'),
            subtitle: const Text('Kejadian yang tercatat'),
            trailing: Icon(unlocked ? Icons.lock_open : Icons.lock_outline,
                size: 18, color: AppColors.textSecondary),
            onTap: () => _openGated(HistoryScreen(services: services)),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Pengaturan'),
            subtitle: const Text('Ambang, suara, getar, PIN'),
            trailing: Icon(unlocked ? Icons.lock_open : Icons.lock_outline,
                size: 18, color: AppColors.textSecondary),
            onTap: () => _openGated(SettingsScreen(services: services)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang'),
            subtitle: const Text('Cara kerja & panduan'),
            onTap: () => _open(const AboutScreen()),
          ),
          if (unlocked)
            ListTile(
              leading: const Icon(Icons.lock, color: AppColors.warning),
              title: const Text('Kunci mode pengajar'),
              onTap: _lock,
            ),
        ],
      ),
    );
  }

  Widget _header(bool unlocked) {
    return DrawerHeader(
      decoration: const BoxDecoration(color: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.visibility, color: AppColors.primary, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Deteksi Mencontek',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.safe : AppColors.textSecondary)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(unlocked ? Icons.lock_open : Icons.lock,
                    size: 12, color: unlocked ? AppColors.safe : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  unlocked ? 'Mode pengajar aktif' : 'Mode peserta (terkunci)',
                  style: TextStyle(
                      color: unlocked ? AppColors.safe : AppColors.textSecondary,
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
