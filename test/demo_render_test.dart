// Rekam layar aplikasi sebagai bingkai PNG untuk GIF demo, tanpa emulator: layar digambar di laptop dalam mode demo,
// lalu disusun menjadi GIF dalam bingkai ponsel. Jalankan:
//   DEMO_FRAMES=build/frames flutter test test/demo_render_test.dart
//   python3 tool/render_gif.py build/frames docs/images/demo.gif
import 'dart:io';

import 'package:cerdas/main.dart';
import 'package:cerdas/services/alarm_service.dart';
import 'package:cerdas/services/app_services.dart';
import 'package:cerdas/services/detection_log.dart';
import 'package:cerdas/services/session_store.dart';
import 'package:cerdas/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo/demo_recorder.dart';

void main() {
  final out = Platform.environment['DEMO_FRAMES'];
  testWidgets('bingkai demo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => loadFonts({
        for (final family in ['Poppins', 'Inter'])
          family: [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/$family-$w.ttf'],
      }),
    );
    final s = AppServices(settings: SettingsService(), log: DetectionLog(), sessions: SessionStore(), alarm: AlarmService());
    await Future.wait([s.settings.load(), s.log.load(), s.sessions.load()]);
    s.settings.setSound(false);
    if (out != null) Directory(out).createSync(recursive: true);
    final r = DemoRecorder(tester, out)..prepare();
    await tester.pumpWidget(r.wrap(CheatDetectionApp(services: s, startInDemo: true, enableCamera: false)));

    // 1. pembuka: diketik, sudut bidik mengunci, garis pindai, lalu wajah diketuk supaya menoleh
    r.scene = 'pembuka';
    await r.run(4600);
    final screen = tester.getRect(find.byType(CheatDetectionApp));
    await r.tapAt(Offset(screen.width * .2, screen.height * .4), after: 1200);
    await r.tapAt(Offset(screen.width * .8, screen.height * .4), after: 2800);
    await r.settle();

    // 2. mode demo: siaga, lalu pengajar membuat PIN dan memulai sesi
    r.scene = 'siaga';
    await r.run(2000);
    await r.tap(find.text('Mulai sesi ujian'), after: 500);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1234');
    await tester.enterText(fields.at(1), '1234');
    await r.run(400);
    await r.tap(find.text('Simpan'), after: 500);
    await r.tap(find.text('Mulai'), after: 300);

    // 3. sesi berjalan: peserta menoleh dan peringatan muncul
    r.scene = 'sesi';
    await r.run(7000);

    // 4. pengajar mengakhiri sesi dan melihat ringkasan
    r.scene = 'ringkasan';
    await r.tap(find.text('Akhiri sesi (PIN pengajar)'), after: 400);
    await tester.enterText(find.byType(TextField), '1234');
    await r.run(300);
    await r.tap(find.text('Buka'), after: 1500);
    await r.scroll(-500);
    await r.run(1500);
    r.finish();
  }, skip: out == null);
}
