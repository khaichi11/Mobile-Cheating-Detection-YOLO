import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Menyimpan tangkapan layar dari integration test ke docs/images.
Future<void> main() {
  return integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('docs/images/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
