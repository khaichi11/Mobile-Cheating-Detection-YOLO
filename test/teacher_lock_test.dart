import 'package:cerdas/services/alarm_service.dart';
import 'package:cerdas/services/app_services.dart';
import 'package:cerdas/services/detection_log.dart';
import 'package:cerdas/services/session_store.dart';
import 'package:cerdas/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lima PIN salah mengunci sementara, makin lama bila diulang', () {
    final s = AppServices(
      settings: SettingsService(),
      log: DetectionLog(),
      sessions: SessionStore(),
      alarm: AlarmService(),
    );
    final t0 = DateTime(2026, 6, 1, 8);
    for (var i = 0; i < 4; i++) {
      s.registerPinFailure(t0);
    }
    expect(s.pinLockRemaining(t0), Duration.zero);
    s.registerPinFailure(t0);
    expect(s.pinLockRemaining(t0), const Duration(seconds: 30));
    expect(s.pinLockRemaining(t0.add(const Duration(seconds: 31))), Duration.zero);
    for (var i = 0; i < 5; i++) {
      s.registerPinFailure(t0);
    }
    expect(s.pinLockRemaining(t0), const Duration(minutes: 1));
    s.registerPinSuccess();
    expect(s.pinFailures, 0);
    expect(s.pinLockRemaining(t0), Duration.zero);
  });
}
