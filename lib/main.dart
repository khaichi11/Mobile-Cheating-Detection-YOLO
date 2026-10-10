import 'package:flutter/material.dart';

import 'screens/detection_screen.dart';
import 'services/alarm_service.dart';
import 'services/app_services.dart';
import 'services/detection_log.dart';
import 'services/session_store.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/proctor_intro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi service bersama sebelum UI tampil.
  final settings = SettingsService();
  final log = DetectionLog();
  final sessions = SessionStore();
  final alarm = AlarmService();
  await Future.wait([settings.load(), log.load(), sessions.load(), alarm.init()]);

  runApp(CheatDetectionApp(
    services: AppServices(settings: settings, log: log, sessions: sessions, alarm: alarm),
  ));
}

class CheatDetectionApp extends StatefulWidget {
  final AppServices services;
  final bool startInDemo;
  final bool enableCamera;

  /// Tampilkan pembuka saat aplikasi dibuka (dimatikan di uji widget).
  final bool intro;

  const CheatDetectionApp({
    super.key,
    required this.services,
    this.startInDemo = false,
    this.enableCamera = true,
    this.intro = true,
  });

  @override
  State<CheatDetectionApp> createState() => _CheatDetectionAppState();
}

class _CheatDetectionAppState extends State<CheatDetectionApp> {
  late bool _introDone = !widget.intro;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CERDAS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _introDone
            ? DetectionScreen(
                services: widget.services,
                startInDemo: widget.startInDemo,
                enableCamera: widget.enableCamera,
              )
            : ProctorIntro(onDone: () => setState(() => _introDone = true)),
      ),
    );
  }
}
