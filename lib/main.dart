import 'package:flutter/material.dart';

import 'screens/detection_screen.dart';
import 'services/alarm_service.dart';
import 'services/app_services.dart';
import 'services/detection_log.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi service bersama sebelum UI tampil.
  final settings = SettingsService();
  final log = DetectionLog();
  final alarm = AlarmService();
  await Future.wait([settings.load(), log.load(), alarm.init()]);

  runApp(CheatDetectionApp(
    services: AppServices(settings: settings, log: log, alarm: alarm),
  ));
}

class CheatDetectionApp extends StatelessWidget {
  final AppServices services;

  const CheatDetectionApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deteksi Mencontek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: DetectionScreen(services: services),
    );
  }
}
