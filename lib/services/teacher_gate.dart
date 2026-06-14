import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_services.dart';

/// Gerbang akses pengajar.
///
/// Riwayat (termasuk ekspor CSV & hapus) dan Pengaturan hanya bisa dibuka
/// setelah pengajar memasukkan PIN. Tujuannya mencegah peserta ujian
/// memanipulasi data atau mematikan deteksi.
///
/// Begitu terbuka, status bertahan selama sesi aplikasi (lihat
/// [AppServices.teacherUnlocked]) sampai dikunci ulang atau aplikasi ditutup.
class TeacherGate {
  /// Pastikan akses pengajar. Mengembalikan true bila boleh lanjut.
  static Future<bool> ensureAccess(BuildContext context, AppServices s) async {
    if (s.teacherUnlocked) return true;

    if (!s.settings.hasTeacherPin) {
      final created = await _createPinDialog(context, s);
      if (created) s.teacherUnlocked = true;
      return created;
    }

    final ok = await _enterPinDialog(context, s);
    if (ok) s.teacherUnlocked = true;
    return ok;
  }

  /// Dialog membuat PIN baru (saat pertama kali atau saat mengganti).
  static Future<bool> _createPinDialog(BuildContext context, AppServices s) async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Buat PIN Pengajar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PIN ini melindungi Riwayat, ekspor CSV, dan Pengaturan agar tidak '
                'diubah peserta. Simpan baik-baik.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _pinField(pin, 'PIN baru (4-6 digit)'),
              const SizedBox(height: 12),
              _pinField(confirm, 'Ulangi PIN'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final p = pin.text.trim();
                if (p.length < 4) {
                  setState(() => error = 'PIN minimal 4 digit.');
                } else if (p != confirm.text.trim()) {
                  setState(() => error = 'PIN tidak cocok.');
                } else {
                  s.settings.setTeacherPin(p);
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// Dialog memasukkan PIN yang sudah ada.
  static Future<bool> _enterPinDialog(BuildContext context, AppServices s) async {
    final pin = TextEditingController();
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Akses Pengajar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan PIN pengajar untuk membuka.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              _pinField(pin, 'PIN'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (pin.text.trim() == s.settings.teacherPin) {
                  Navigator.pop(ctx, true);
                } else {
                  setState(() => error = 'PIN salah.');
                }
              },
              child: const Text('Buka'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// Ganti PIN (mewajibkan verifikasi PIN lama lebih dulu).
  static Future<void> changePin(BuildContext context, AppServices s) async {
    if (s.settings.hasTeacherPin) {
      final ok = await _enterPinDialog(context, s);
      if (!ok) return;
    }
    if (!context.mounted) return;
    await _createPinDialog(context, s);
  }

  static Widget _pinField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
