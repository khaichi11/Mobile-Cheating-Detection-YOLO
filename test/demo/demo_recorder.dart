// ignore_for_file: avoid_print
// Perekam bingkai demo: menggambar layar di laptop tanpa emulator, menyimpan PNG setiap 100 ms, dan menandai setiap
// ketukan dengan lingkaran supaya interaksinya terlihat di GIF. Dipakai oleh test/demo_render_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Muat huruf dari assets/fonts dan ikon Material, karena pengujian biasanya memakai huruf kotak-kotak.
Future<void> loadFonts(Map<String, List<String>> families) async {
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

class DemoRecorder {
  DemoRecorder(this.tester, this.out);

  final WidgetTester tester;
  final String? out;
  final key = GlobalKey();
  final touch = ValueNotifier<(Offset, double)?>(null);
  final _manifest = <Map<String, dynamic>>[];
  var _frame = 0;
  String scene = '';

  /// Ukuran layar ponsel 360 x 780 dp dengan ruang bilah status (24 dp) dan garis gestur (16 dp), seperti ponsel
  /// sungguhan, supaya bilah aplikasi ikut mewarnai area bilah status. Bayangan digambar sungguhan; pengujian Flutter
  /// biasanya menggantinya dengan garis hitam.
  void prepare() {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 72, bottom: 48);
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
  }

  /// Bungkus aplikasi supaya bisa direkam dan ketukannya terlihat.
  Widget wrap(Widget app) => RepaintBoundary(
    key: key,
    child: Stack(
      textDirection: TextDirection.ltr,
      children: [
        app,
        ValueListenableBuilder(
          valueListenable: touch,
          builder: (_, t, _) => t == null
              ? const SizedBox.shrink()
              : Positioned(
                  left: t.$1.dx - 22 - 10 * t.$2,
                  top: t.$1.dy - 22 - 10 * t.$2,
                  child: IgnorePointer(
                    child: Container(
                      width: 44 + 20 * t.$2,
                      height: 44 + 20 * t.$2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: .18 * (1 - t.$2)),
                        border: Border.all(color: Colors.white.withValues(alpha: .7 * (1 - t.$2)), width: 2),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );

  Future<void> capture() async {
    final dir = out;
    if (dir == null) return;
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final name = 'f${(_frame++).toString().padLeft(4, '0')}.png';
      File('$dir/$name').writeAsBytesSync(png!.buffer.asUint8List());
      _manifest.add({'file': name, 'scene': scene, 'ms': 100});
    });
  }

  /// Gambar setiap 33 ms seperti layar 30 fps, simpan setiap 100 ms.
  Future<void> run(int ms) async {
    for (var t = 0; t < ms; t += 99) {
      for (var k = 0; k < 3; k++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await capture();
    }
  }

  /// Biarkan gambar dan pekerjaan asinkron selesai di luar jam palsu pengujian.
  Future<void> settle([int ms = 300]) => tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

  Future<void> tapAt(Offset at, {int after = 600}) async {
    for (var i = 0; i < 3; i++) {
      touch.value = (at, i / 6);
      await run(99);
    }
    await tester.tapAt(at);
    for (var i = 3; i < 6; i++) {
      touch.value = (at, i / 6);
      await run(99);
    }
    touch.value = null;
    await run(after);
  }

  Future<void> tap(Finder f, {int after = 600}) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tapAt(tester.getCenter(f), after: after);
  }

  /// Gulir pelan supaya terlihat seperti digeser jari.
  Future<void> scroll(double dy, {int steps = 10, Finder? within}) async {
    final target = within ?? find.byType(Scrollable).first;
    for (var i = 0; i < steps; i++) {
      await tester.drag(target, Offset(0, dy / steps));
      await run(99);
    }
  }

  void finish() {
    debugDisableShadows = true;
    final dir = out;
    if (dir != null) {
      File('$dir/manifest.json').writeAsStringSync(jsonEncode(_manifest));
    }
  }
}
