// Tangkapan layar dokumentasi di emulator, memakai mode demo (wajah dummy)
// sehingga model sungguhan dijalankan tanpa kamera dan tanpa wajah asli.
//
// Jalankan: flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/screenshots_test.dart

import 'package:cerdas/main.dart';
import 'package:cerdas/services/alarm_service.dart';
import 'package:cerdas/services/app_services.dart';
import 'package:cerdas/services/detection_log.dart';
import 'package:cerdas/services/session_store.dart';
import 'package:cerdas/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tangkapan layar semua layar (mode demo)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final services = AppServices(
      settings: SettingsService(),
      log: DetectionLog(),
      sessions: SessionStore(),
      alarm: AlarmService(),
    );
    await Future.wait([services.settings.load(), services.log.load(), services.sessions.load()]);
    services.settings.setSound(false);
    await binding.convertFlutterSurfaceToImage();

    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> waitFor(Finder f, {int seconds = 40}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('Tidak muncul: $f');
    }

    Future<void> shoot(String name) async {
      await settle(4);
      await binding.takeScreenshot(name);
    }

    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await settle(2);
      await tester.tap(f);
      await settle();
    }

    Future<void> enterPin({bool create = false}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1234');
      if (create) await tester.enterText(fields.at(1), '1234');
      await tap(find.text(create ? 'Simpan' : 'Buka'));
    }

    await tester.pumpWidget(CheatDetectionApp(services: services, startInDemo: true, intro: false));
    await waitFor(find.text('Fokus ke depan'));
    await settle(10);
    await shoot('01-siaga');

    // Memulai sesi: PIN pengajar dibuat saat pertama kali.
    await tap(find.text('Mulai sesi ujian'));
    await shoot('02-pin-pengajar');
    await enterPin(create: true);
    await shoot('03-mulai-sesi');
    await tap(find.text('Mulai'));

    // Tunggu adegan menoleh sampai peringatan aktif, lalu ambil segera.
    await waitFor(find.textContaining('Indikasi tercatat'));
    await settle(2);
    await shoot('04-peringatan-menoleh');

    await waitFor(find.text('Fokus ke depan'));
    await settle(8);
    await shoot('05-sesi-fokus');

    await tap(find.byTooltip('Info teknis'));
    await shoot('06-info-teknis');
    await tap(find.byTooltip('Info teknis'));

    // Biarkan satu putaran skenario demo selesai agar ringkasan berisi.
    await waitFor(find.text('Menengadah ke atas'), seconds: 60);
    await waitFor(find.text('Fokus ke depan'));
    await settle(10);
    await tap(find.text('Akhiri sesi (PIN pengajar)'));
    await enterPin();
    await waitFor(find.text('Ringkasan sesi'));
    await shoot('07-ringkasan-sesi');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await shoot('08-ringkasan-kejadian');
    await tester.pageBack();
    await settle();

    await tap(find.byTooltip('Menu'));
    await shoot('09-menu');

    await tap(find.text('Riwayat'));
    final pin = find.text('Akses Pengajar');
    if (pin.evaluate().isNotEmpty) await enterPin();
    await waitFor(find.text('total kejadian'));
    await shoot('10-riwayat-sesi');
    await tap(find.textContaining('Kejadian ('));
    await shoot('11-riwayat-kejadian');
    await tester.pageBack();
    await settle();

    await tap(find.byTooltip('Menu'));
    await tap(find.text('Pengaturan'));
    if (find.text('Akses Pengajar').evaluate().isNotEmpty) await enterPin();
    await shoot('12-pengaturan');
    await tester.pageBack();
    await settle();

    await tap(find.byTooltip('Menu'));
    await tap(find.text('Tentang'));
    await shoot('13-tentang');
  });
}
