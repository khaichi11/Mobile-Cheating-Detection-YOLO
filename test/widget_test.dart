// Uji widget layar-layar utama tanpa kamera/plugin native.

import 'package:cerdas/main.dart';
import 'package:cerdas/models/detection_event.dart';
import 'package:cerdas/models/exam_session.dart';
import 'package:cerdas/models/gaze_direction.dart';
import 'package:cerdas/screens/history_screen.dart';
import 'package:cerdas/screens/session_summary_screen.dart';
import 'package:cerdas/screens/settings_screen.dart';
import 'package:cerdas/services/alarm_service.dart';
import 'package:cerdas/services/app_services.dart';
import 'package:cerdas/services/detection_log.dart';
import 'package:cerdas/services/session_store.dart';
import 'package:cerdas/services/settings_service.dart';
import 'package:cerdas/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppServices> _services() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppServices(
    settings: SettingsService(),
    log: DetectionLog(),
    sessions: SessionStore(),
    alarm: AlarmService(),
  );
  await Future.wait([s.settings.load(), s.log.load(), s.sessions.load()]);
  return s;
}

ExamSession _sampleSession() => ExamSession(
      id: 'sesi-1',
      name: 'UTS Matematika 12A',
      start: DateTime(2026, 10, 6, 8, 0),
      end: DateTime(2026, 10, 6, 9, 30),
      focusMs: 80 * 60 * 1000,
      awayMs: 6 * 60 * 1000,
      absentMs: 4 * 60 * 1000,
      longestAwayMs: 4200,
      incidents: {GazeDirection.kiri: 3, GazeDirection.bawah: 2, GazeDirection.hilang: 1},
    );

Future<void> _createPin(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '1234');
  await tester.enterText(fields.at(1), '1234');
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Ukuran layar ponsel umum (1080 x 2400) agar tata letak diuji realistis.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('layar deteksi tampil dan sesi bisa dimulai', (tester) async {
    _phone(tester);
    final s = await _services();
    await tester.pumpWidget(CheatDetectionApp(services: s, enableCamera: false));
    await tester.pump();

    expect(find.text('Siaga · cek posisi kamera'), findsOneWidget);
    expect(find.text('Wajah belum terlihat'), findsOneWidget);

    // Memulai sesi wajib PIN pengajar (dibuat saat pertama kali).
    await tester.tap(find.text('Mulai sesi ujian'));
    await tester.pumpAndSettle();
    expect(find.text('Buat PIN Pengajar'), findsOneWidget);
    await _createPin(tester);
    await tester.enterText(find.byType(TextField), 'Kuis Fisika');
    await tester.tap(find.text('60 mnt'));
    await tester.pump();
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Kuis Fisika'), findsOneWidget);
    expect(find.text('Akhiri sesi (PIN pengajar)'), findsOneWidget);
    expect(find.text('Sisa waktu'), findsOneWidget);
    expect(s.teacherUnlocked, isFalse, reason: 'akses terkunci lagi saat sesi dimulai');
  });

  testWidgets('peserta tidak bisa mengakhiri sesi tanpa PIN', (tester) async {
    _phone(tester);
    final s = await _services();
    s.settings.setTeacherPin('2468');
    s.unlockTeacher();
    await tester.pumpWidget(CheatDetectionApp(services: s, enableCamera: false));
    await tester.pump();
    await tester.tap(find.text('Mulai sesi ujian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akhiri sesi (PIN pengajar)'));
    await tester.pumpAndSettle();
    expect(find.text('Akses Pengajar'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('PIN salah.'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Akhiri sesi (PIN pengajar)'), findsOneWidget, reason: 'sesi tetap berjalan');
    expect(s.sessions.sessions, isEmpty);

    await tester.tap(find.text('Akhiri sesi (PIN pengajar)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan sesi'), findsOneWidget);
    expect(s.sessions.sessions.single.endedBy, 'pengajar');
  });

  testWidgets('drawer menampilkan menu dan status kunci', (tester) async {
    _phone(tester);
    final s = await _services();
    await tester.pumpWidget(CheatDetectionApp(services: s, enableCamera: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Mode demo'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Akses pengajar terkunci'), findsOneWidget);
  });

  testWidgets('riwayat kosong menampilkan petunjuk', (tester) async {
    _phone(tester);
    final s = await _services();
    await tester.pumpWidget(_wrap(HistoryScreen(services: s)));
    expect(find.textContaining('Belum ada sesi'), findsOneWidget);
    await tester.tap(find.textContaining('Kejadian ('));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada kejadian tercatat.'), findsOneWidget);
  });

  testWidgets('riwayat menampilkan sesi dan kejadian', (tester) async {
    _phone(tester);
    final s = await _services();
    s.sessions.add(_sampleSession());
    s.log.add(DetectionEvent(
      direction: GazeDirection.kiri,
      confidence: 0.91,
      time: DateTime(2026, 10, 6, 8, 12, 5),
      duration: const Duration(milliseconds: 1500),
      sessionId: 'sesi-1',
    ));
    await tester.pumpWidget(_wrap(HistoryScreen(services: s)));
    expect(find.text('UTS Matematika 12A'), findsOneWidget);
    await tester.tap(find.textContaining('Kejadian ('));
    await tester.pumpAndSettle();
    expect(find.text('Menoleh ke kiri'), findsOneWidget);
    expect(find.textContaining('UTS Matematika 12A'), findsOneWidget);
  });

  testWidgets('ringkasan sesi menghitung fokus dan kejadian', (tester) async {
    _phone(tester);
    final s = await _services();
    final session = _sampleSession();
    await tester.pumpWidget(_wrap(SessionSummaryScreen(services: s, session: session)));
    // 80 / (80 + 6) = 93%
    expect(find.text('93%'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.textContaining('paling sering "kiri"'), findsOneWidget);
  });

  testWidgets('pengaturan menyimpan perubahan', (tester) async {
    _phone(tester);
    final s = await _services();
    await tester.pumpWidget(_wrap(SettingsScreen(services: s)));
    expect(find.text('70%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Getar'), 200);
    await tester.tap(find.text('Getar'));
    await tester.pumpAndSettle();
    expect(s.settings.vibrationEnabled, isFalse);
  });
}
