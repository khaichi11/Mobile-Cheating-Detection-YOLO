import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic/proctor_engine.dart';
import '../models/detection_event.dart';
import '../models/exam_session.dart';
import '../models/gaze_direction.dart';
import '../services/app_services.dart';
import '../services/demo_feed.dart';
import '../services/settings_service.dart';
import '../services/teacher_gate.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_drawer.dart';
import '../widgets/status_panel.dart';
import '../widgets/timeline_strip.dart';
import '../widgets/face_guide.dart';
import 'session_summary_screen.dart';

/// Layar utama: kamera langsung (atau mode demo) + deteksi arah pandang.
///
/// Aturan sesi:
/// - Di luar sesi aplikasi dalam mode siaga: status tampil tanpa alarm/catatan.
/// - Memulai dan mengakhiri sesi wajib PIN pengajar (juga di mode demo).
/// - Sesi berakhir otomatis saat waktu habis.
/// - Selama sesi: tombol kembali dikunci, ganti kamera dan mode demo butuh PIN,
///   dan meninggalkan aplikasi dicatat sebagai kejadian.
///
/// Demi kelancaran (target 30 FPS), layar ini tidak memanggil `setState` per
/// frame. Hasil kamera masuk ke [ProctorEngine]; bagian UI yang berubah
/// mendengarkan notifier masing-masing.
class DetectionScreen extends StatefulWidget {
  final AppServices services;

  /// Langsung masuk mode demo (dipakai untuk uji dan tangkapan layar).
  final bool startInDemo;

  /// Matikan kamera sungguhan (dipakai di uji widget tanpa plugin).
  final bool enableCamera;

  const DetectionScreen({
    super.key,
    required this.services,
    this.startInDemo = false,
    this.enableCamera = true,
  });

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> with WidgetsBindingObserver {
  late final ProctorEngine _engine;
  final YOLOViewController _controller = YOLOViewController();
  DemoFeed? _demo;

  bool _demoMode = false;
  bool _demoLoading = false;
  bool _hasPermission = false;
  bool _checkingPermission = true;
  bool _showTech = false;
  bool _paused = false;
  bool _ending = false;
  String? _modelError;
  DateTime? _leftAt;

  late final LensFacing _initialLens;
  late bool _isFront;

  final ValueNotifier<int> _tick = ValueNotifier(0);
  final ValueNotifier<YOLOPerformanceMetrics?> _perf = ValueNotifier(null);
  DateTime _lastPerf = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _ticker;

  SettingsService get _settings => widget.services.settings;
  ExamSession? get _session => _engine.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = ProctorEngine(
      config: () => _settings.engineConfig,
      onIncident: _onIncident,
    );
    _isFront = _settings.defaultFrontCamera;
    _initialLens = _isFront ? LensFacing.front : LensFacing.back;
    _settings.addListener(_onSettingsChanged);
    _applyWakelock();

    // Garis waktu, timer sesi, dan aturan berbasis waktu cukup diperbarui
    // empat kali per detik.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_paused) return;
      _engine.tick();
      _tick.value++;
      final s = _session;
      if (s != null && s.remaining(DateTime.now()) == Duration.zero) {
        _endSession(auto: true);
      }
    });

    if (widget.startInDemo) {
      _checkingPermission = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterDemo());
    } else if (widget.enableCamera) {
      _requestPermission();
    } else {
      _checkingPermission = false;
    }
  }

  // ── Kamera & izin ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _hasPermission = status.isGranted;
      _checkingPermission = false;
    });
  }

  void _onSettingsChanged() {
    _applyWakelock();
    _applyThresholds();
  }

  Future<void> _applyWakelock() async {
    try {
      await WakelockPlus.toggle(enable: _settings.keepScreenAwake);
    } catch (_) {/* abaikan bila platform tak mendukung */}
  }

  Future<void> _applyThresholds() async {
    if (_demoMode || !_hasPermission) return;
    try {
      // Ambang native sedikit lebih longgar; penyaringan akhir dilakukan
      // ProctorEngine dengan ambang dari Pengaturan.
      final native = (_settings.confidenceThreshold - 0.1).clamp(0.25, 0.9);
      await _controller.setThresholds(
        confidenceThreshold: native,
        iouThreshold: 0.5,
        numItemsThreshold: 3,
      );
    } catch (e) {
      debugPrint('Gagal set threshold: $e');
    }
  }

  Future<void> _onModelLoaded() async {
    try {
      // Kotak bawaan plugin disembunyikan agar wajah tidak tertutup.
      await _controller.setShowOverlays(false);
    } catch (_) {}
    await _applyThresholds();
  }

  Future<void> _switchCamera() async {
    if (_session != null) {
      final ok = await TeacherGate.ensureAccess(context, widget.services);
      if (!ok) return;
    }
    try {
      await _controller.switchCamera();
      _isFront = !_isFront;
      _engine.reset();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Gagal pindah kamera: $e');
    }
  }

  void _onResult(List<YOLOResult> results) {
    if (_demoMode || _paused) return;
    _engine.ingest([
      for (final r in results)
        Detection(GazeDirectionInfo.fromClassName(r.className), r.confidence,
            box: r.normalizedBox),
    ]);
  }

  void _onPerf(YOLOPerformanceMetrics m) {
    final now = DateTime.now();
    if (now.difference(_lastPerf) < const Duration(milliseconds: 500)) return;
    _lastPerf = now;
    _perf.value = m;
  }

  // ── Peringatan ──────────────────────────────────────────────────────────────

  void _onIncident(Incident i) {
    widget.services.alarm.alert(
      sound: _settings.soundEnabled,
      vibrate: _settings.vibrationEnabled,
    );
    if (i.isNewRun && _settings.logEvents) {
      widget.services.log.add(DetectionEvent(
        direction: i.direction,
        confidence: i.confidence,
        time: i.time,
        duration: i.heldFor,
        sessionId: _session?.id,
      ));
    }
  }

  // ── Sesi ujian ──────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    // Hanya pengajar yang boleh memulai sesi agar peserta tidak bisa
    // memulai ulang untuk menghapus catatan.
    final ok = await TeacherGate.ensureAccess(context, widget.services);
    if (!ok || !mounted) return;
    final setup = await showModalBottomSheet<_SessionSetup>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StartSessionSheet(
        initialName: _demoMode ? 'Sesi demo' : defaultSessionName(DateTime.now()),
        initialMinutes: _demoMode ? 0 : _settings.sessionMinutes,
        demo: _demoMode,
      ),
    );
    if (setup == null || !mounted) return;
    final now = DateTime.now();
    _engine.startSession(ExamSession(
      id: now.microsecondsSinceEpoch.toString(),
      name: setup.name,
      start: now,
      isDemo: _demoMode,
      plannedMinutes: setup.minutes == 0 ? null : setup.minutes,
    ));
    widget.services.lockTeacher();
    setState(() {});
  }

  Future<void> _endSession({bool auto = false}) async {
    if (_session == null || _ending) return;
    _ending = true;
    try {
      if (!auto) {
        // Peserta tidak boleh mengakhiri sesi sendiri, termasuk di mode demo.
        final ok = await TeacherGate.ensureAccess(context, widget.services);
        if (!ok || !mounted) return;
      }
      final s = _engine.endSession();
      if (s == null) return;
      s.endedBy = auto ? 'waktu' : 'pengajar';
      widget.services.sessions.add(s);
      widget.services.lockTeacher();
      if (!mounted) return;
      setState(() {});
      await _openPage(SessionSummaryScreen(services: widget.services, session: s));
    } finally {
      _ending = false;
    }
  }

  // ── Mode demo ───────────────────────────────────────────────────────────────

  Future<void> _enterDemo() async {
    if (_session != null) {
      _snack('Mode demo tidak bisa dibuka selama sesi berjalan');
      return;
    }
    setState(() {
      _demoMode = true;
      _demoLoading = true;
    });
    _engine.reset();
    final demo = DemoFeed(onFrame: (d) {
      if (!_paused) _engine.ingest(d);
    });
    _demo = demo;
    await demo.prepare();
    if (!mounted || _demo != demo) return;
    demo.start();
    setState(() => _demoLoading = false);
  }

  void _exitDemo() {
    if (_session != null) {
      _snack('Akhiri sesi demo dulu');
      return;
    }
    _demo?.dispose();
    _demo = null;
    _engine.reset();
    setState(() => _demoMode = false);
    if (widget.enableCamera && !_hasPermission) _requestPermission();
  }

  // ── Navigasi & siklus hidup ─────────────────────────────────────────────────

  /// Buka layar lain sambil menjeda kamera agar tidak memboroskan baterai
  /// dan tidak membunyikan alarm saat pengajar sedang di layar lain.
  Future<void> _openPage(Widget page) async {
    _pause();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _resume();
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _demo?.stop();
    if (!_demoMode && _hasPermission) _controller.pause().catchError((_) {});
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _engine.resumeAfterGap();
    if (_demoMode) {
      _demo?.start();
    } else if (_hasPermission) {
      _controller.resume().catchError((_) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_session != null) _leftAt ??= DateTime.now();
      _pause();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null) _engine.recordLeftApp(DateTime.now().difference(left));
      if (ModalRoute.of(context)?.isCurrent == true) _resume();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Tampilan ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final session = _session;
    return PopScope(
      canPop: session == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _snack('Sesi sedang berjalan. Hanya pengajar yang bisa mengakhirinya.');
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        drawer: AppDrawer(
          services: widget.services,
          demoMode: _demoMode,
          sessionActive: session != null,
          onOpenPage: _openPage,
          onToggleDemo: _demoMode ? _exitDemo : _enterDemo,
        ),
        body: Builder(builder: (context) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _cameraLayer(),
              // Oval panduan wajah; posisinya sedikit di atas tengah layar,
              // sejajar dengan letak wajah saat HP diletakkan di depan peserta.
              Align(
                alignment: const Alignment(0, -0.16),
                child: ValueListenableBuilder<LiveStatus>(
                  valueListenable: _engine.status,
                  builder: (_, s, _) => FaceGuide(
                    color: s.state == DetectionState.noFace
                        ? Colors.white.withValues(alpha: 0.7)
                        : (s.alerting ? AppColors.danger : colorForState(s.state)),
                  ),
                ),
              ),
              _alertEdge(),
              Positioned(top: 0, left: 0, right: 0, child: _topBar(context, pad.top)),
              if (_showTech)
                Positioned(
                  top: pad.top + 60,
                  left: 12,
                  right: 12,
                  child: _techPanel(),
                ),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomPanel(pad.bottom)),
            ],
          );
        }),
      ),
    );
  }

  Widget _cameraLayer() {
    if (_demoMode) return _demoLayer();
    if (!widget.enableCamera) return const ColoredBox(color: Color(0xFF1C1C1A));
    if (_checkingPermission) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (!_hasPermission) return _permissionView();
    if (_modelError != null) return _errorView(_modelError!);
    return YOLOView(
      key: const ValueKey('kamera'),
      modelPath: DemoFeed.defaultModel,
      task: YOLOTask.detect,
      controller: _controller,
      lensFacing: _initialLens,
      useGpu: true,
      confidenceThreshold: 0.5,
      iouThreshold: 0.5,
      streamingConfig: const YOLOStreamingConfig.minimal(),
      onResult: _onResult,
      onPerformanceMetrics: _onPerf,
      onModelLoad: (_, _) => _onModelLoaded(),
      onModelError: (e, _, _) {
        if (mounted) setState(() => _modelError = '$e');
      },
    );
  }

  Widget _demoLayer() {
    final demo = _demo;
    if (demo == null || _demoLoading) {
      return const ColoredBox(
        color: Color(0xFF1C1C1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Menyiapkan mode demo', style: TextStyle(color: AppColors.onScrimSoft)),
            ],
          ),
        ),
      );
    }
    return ValueListenableBuilder<DemoShot?>(
      valueListenable: demo.current,
      builder: (_, shot, _) {
        if (shot == null) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              shot.asset,
              key: ValueKey(shot.asset),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              width: double.infinity,
              height: double.infinity,
            ),
          ],
        );
      },
    );
  }

  Widget _alertEdge() {
    return IgnorePointer(
      child: ValueListenableBuilder<LiveStatus>(
        valueListenable: _engine.status,
        builder: (_, s, _) => AnimatedOpacity(
          opacity: s.alerting || (_session != null && s.faces >= 2) ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.danger, width: 6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, double topInset) {
    final session = _session;
    Widget icon(IconData i, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(i, color: AppColors.onScrim, size: 22),
        );
    return Container(
      color: AppColors.scrim,
      padding: EdgeInsets.fromLTRB(4, topInset + 4, 4, 6),
      child: Row(
        children: [
          icon(Icons.menu_rounded, 'Menu', () => Scaffold.of(context).openDrawer()),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (_, _, _) {
                final String sub;
                if (session == null) {
                  sub = _demoMode ? 'Mode demo · wajah dummy' : 'Siaga · cek posisi kamera';
                } else {
                  final left = session.remaining(DateTime.now());
                  sub = left == null
                      ? 'Berjalan ${formatClock(session.duration)}'
                      : 'Sisa ${formatClock(left)}';
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session?.name ?? 'CERDAS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: displayStyle(size: 15.5, color: AppColors.onScrim),
                    ),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(size: 12, color: AppColors.onScrimSoft)),
                  ],
                );
              },
            ),
          ),
          if (_demoMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.onScrimSoft),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('DEMO',
                  style: TextStyle(
                      color: AppColors.onScrim, fontSize: 10.5, fontWeight: FontWeight.w700)),
            )
          else
            ValueListenableBuilder<YOLOPerformanceMetrics?>(
              valueListenable: _perf,
              builder: (_, m, _) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(m == null ? '-- fps' : '${m.fps.round()} fps',
                    style: monoStyle(size: 12, color: AppColors.onScrimSoft)),
              ),
            ),
          icon(Icons.speed_rounded, 'Info teknis', () => setState(() => _showTech = !_showTech)),
          if (!_demoMode && _hasPermission)
            icon(Icons.cameraswitch_outlined, _isFront ? 'Pakai kamera belakang' : 'Pakai kamera depan',
                _switchCamera),
        ],
      ),
    );
  }

  Widget _techPanel() {
    return ValueListenableBuilder<int>(
      valueListenable: _tick,
      builder: (_, _, _) {
        final m = _perf.value;
        final lines = <String>[
          'model    gaze_yolo12n_320.tflite · 320 px',
          if (_demoMode)
            'sumber   foto dummy · ${_demo?.liveResults == true ? 'model di perangkat' : 'hasil tersimpan'}'
          else
            'kamera   ${_isFront ? 'depan' : 'belakang'} · GPU bila tersedia',
          if (m != null) ...[
            'fps      ${m.fps.toStringAsFixed(1)}',
            'waktu    ${m.processingTimeMs.toStringAsFixed(1)} ms (pra ${m.preMs.toStringAsFixed(1)}'
                ' · inferensi ${m.inferenceMs.toStringAsFixed(1)} · pasca ${m.postMs.toStringAsFixed(1)})',
          ],
          'frame    ${_engine.frames}',
          'aturan   ≥${formatPercent(_settings.confidenceThreshold)} · '
              '${_settings.stabilityFrames} frame · menoleh ≥${formatSeconds(Duration(milliseconds: _settings.minLookAwayMs))}',
        ];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xD9000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in lines)
                Text(l, style: monoStyle(size: 11, color: AppColors.onScrimSoft)),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomPanel(double bottomInset) {
    final session = _session;
    return ValueListenableBuilder<LiveStatus>(
      valueListenable: _engine.status,
      builder: (_, s, child) {
        final edge = s.alerting ? AppColors.danger : colorForState(s.state);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: edge, width: 4)),
          ),
          padding: EdgeInsets.fromLTRB(18, 14, 18, 12 + bottomInset),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<LiveStatus>(
            valueListenable: _engine.status,
            builder: (_, s, _) => StatusRow(status: s, inSession: session != null),
          ),
          const SizedBox(height: 12),
          TimelineStrip(engine: _engine, repaint: _tick),
          if (session != null) ...[
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (_, _, _) {
                final left = session.remaining(DateTime.now());
                return InlineStats([
                  InlineStat(
                    label: left == null ? 'Berjalan' : 'Sisa waktu',
                    value: formatClock(left ?? session.duration),
                  ),
                  InlineStat(
                    label: 'Kejadian',
                    value: '${session.totalIncidents}',
                    valueColor: session.totalIncidents > 0 ? AppColors.danger : null,
                  ),
                  InlineStat(
                    label: 'Fokus',
                    value: session.focusMs + session.awayMs == 0
                        ? '--'
                        : formatPercent(session.focusRatio),
                  ),
                ]);
              },
            ),
          ],
          const SizedBox(height: 14),
          session == null
              ? FilledButton(
                  onPressed: _startSession,
                  child: const Text('Mulai sesi ujian'),
                )
              : OutlinedButton(
                  onPressed: _endSession,
                  child: const Text('Akhiri sesi (PIN pengajar)'),
                ),
        ],
      ),
    );
  }

  Widget _permissionView() => ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 80, 28, 280),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Izinkan kamera', style: displayStyle(size: 24)),
                const SizedBox(height: 8),
                const Text(
                  'Kamera dipakai untuk membaca arah kepala. Gambar diproses di perangkat '
                  'dan tidak disimpan maupun dikirim.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final st = await Permission.camera.status;
                    if (st.isPermanentlyDenied) {
                      await openAppSettings();
                    } else {
                      await _requestPermission();
                    }
                  },
                  child: const Text('Izinkan kamera'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _enterDemo, child: const Text('Coba mode demo')),
              ],
            ),
          ),
        ),
      );

  Widget _errorView(String msg) => ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 100, 28, 280),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Model gagal dimuat', style: displayStyle(size: 22)),
              const SizedBox(height: 8),
              Text(msg,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _ticker?.cancel();
    _demo?.dispose();
    _engine.dispose();
    _tick.dispose();
    _perf.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}

class _SessionSetup {
  final String name;

  /// 0 = tanpa batas waktu.
  final int minutes;

  const _SessionSetup(this.name, this.minutes);
}

/// Lembar pengaturan sesi: nama dan durasi ujian.
class _StartSessionSheet extends StatefulWidget {
  final String initialName;
  final int initialMinutes;
  final bool demo;

  const _StartSessionSheet({
    required this.initialName,
    required this.initialMinutes,
    required this.demo,
  });

  @override
  State<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<_StartSessionSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late int _minutes = widget.initialMinutes;

  static const _options = [30, 45, 60, 90, 120, 0];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _name.text.trim();
    Navigator.pop(context, _SessionSetup(v.isEmpty ? widget.initialName : v, _minutes));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mulai sesi ujian', style: displayStyle(size: 21)),
          const SizedBox(height: 6),
          Text(
            widget.demo
                ? 'Sesi demo memakai foto wajah dummy dan ditandai terpisah di riwayat.'
                : 'Selama sesi, kejadian dicatat dan alarm aktif. Sesi berakhir otomatis saat '
                    'waktu habis; mengakhiri lebih awal butuh PIN pengajar.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Nama sesi'),
          ),
          const SizedBox(height: 18),
          const Text('Durasi ujian',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _options)
                ChoiceChip(
                  label: Text(m == 0 ? 'Tanpa batas' : '$m mnt'),
                  selected: _minutes == m,
                  labelStyle: TextStyle(
                    color: _minutes == m ? AppColors.onPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _submit, child: const Text('Mulai')),
        ],
      ),
    );
  }
}
