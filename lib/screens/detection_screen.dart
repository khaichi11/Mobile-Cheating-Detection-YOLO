import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart' show YOLOViewController;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/detection_event.dart';
import '../models/gaze_direction.dart';
import '../services/app_services.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/status_banner.dart';

/// Layar utama: kamera langsung + deteksi YOLO arah pandang.
class DetectionScreen extends StatefulWidget {
  final AppServices services;

  const DetectionScreen({super.key, required this.services});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  // Satu model untuk kedua kamera (deteksi arah pandang kepala).
  static const String _model = 'best_float16(revfix).tflite';

  YOLOViewController? controller;
  List<YOLOResult> results = [];
  bool hasPermission = false;
  bool isLoading = true;
  bool isFrontCamera = true;

  String? _lastStableClass;
  int _sameClassCount = 0;

  double currentFPS = 0.0;
  double processingTime = 0.0;
  int frameCount = 0;
  bool debugMode = false;

  DateTime? _lastAlertTime;

  SettingsService get _settings => widget.services.settings;

  @override
  void initState() {
    super.initState();
    controller = YOLOViewController();
    isFrontCamera = _settings.defaultFrontCamera;
    _settings.addListener(_onSettingsChanged);
    _requestPermission();
    _initializeController();
    _applyWakelock();

    if (_settings.defaultFrontCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), _switchToFrontCamera);
      });
    }
  }

  void _onSettingsChanged() {
    _applyWakelock();
    _initializeController();
    if (mounted) setState(() {});
  }

  Future<void> _applyWakelock() async {
    try {
      await WakelockPlus.toggle(enable: _settings.keepScreenAwake);
    } catch (_) {/* abaikan bila platform tak mendukung */}
  }

  Future<void> _initializeController() async {
    try {
      await controller?.setThresholds(
        confidenceThreshold: _settings.confidenceThreshold,
        iouThreshold: 0.5,
        numItemsThreshold: 1,
      );
    } catch (e) {
      debugPrint('Gagal set threshold: $e');
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      hasPermission = status.isGranted;
      isLoading = false;
    });
  }

  Future<void> _switchToFrontCamera() async {
    try {
      await controller?.switchCamera();
      await controller?.switchModel(_model, YOLOTask.detect);
      if (!mounted) return;
      setState(() {
        isFrontCamera = true;
        _lastStableClass = null;
        _sameClassCount = 0;
      });
    } catch (e) {
      debugPrint('Gagal pindah ke kamera depan: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await controller?.switchCamera();
      await controller?.switchModel(_model, YOLOTask.detect);
      if (!mounted) return;
      setState(() {
        isFrontCamera = !isFrontCamera;
        _lastStableClass = null;
        _sameClassCount = 0;
        frameCount = 0;
      });
    } catch (e) {
      debugPrint('Gagal pindah kamera: $e');
    }
  }

  void _onResult(List<YOLOResult> detectionResults) {
    frameCount++;
    final th = _settings.confidenceThreshold;

    final filtered = detectionResults.where((r) => r.confidence >= th).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final top = filtered.take(3).toList();

    if (top.isEmpty) {
      if (results.isNotEmpty) setState(() => results = []);
      return;
    }

    final currentClass = top.first.className;
    if (currentClass == _lastStableClass) {
      _sameClassCount++;
    } else {
      _lastStableClass = currentClass;
      _sameClassCount = 1;
    }

    if (_sameClassCount >= _settings.stabilityFrames) {
      setState(() => results = top);
      _maybeAlert(top.first);
    }
  }

  /// Bunyikan alarm + catat riwayat saat arah mencontek stabil terdeteksi,
  /// dengan cooldown agar tidak terus-menerus berbunyi.
  void _maybeAlert(YOLOResult top) {
    final dir = GazeDirectionInfo.fromClassName(top.className);
    if (!dir.isCheating) return;

    final now = DateTime.now();
    final cd = Duration(seconds: _settings.alertCooldownSec);
    if (_lastAlertTime != null && now.difference(_lastAlertTime!) < cd) return;
    _lastAlertTime = now;

    widget.services.alarm.alert(
      sound: _settings.soundEnabled,
      vibrate: _settings.vibrationEnabled,
    );

    if (_settings.logEvents) {
      widget.services.log.add(DetectionEvent(
        direction: dir,
        confidence: top.confidence,
        time: now,
      ));
    }
  }

  // ── Penilaian status saat ini ───────────────────────────────────────────────
  GazeDirection get _currentDirection => results.isEmpty
      ? GazeDirection.unknown
      : GazeDirectionInfo.fromClassName(results.first.className);

  double get _topConfidence => results.isEmpty ? 0.0 : results.first.confidence;

  DetectionState get _state {
    if (results.isEmpty || _topConfidence < _settings.confidenceThreshold) {
      return DetectionState.noFace;
    }
    return _currentDirection.isCheating ? DetectionState.cheating : DetectionState.honest;
  }

  String _confidenceLabel(double c) {
    if (c > 0.9) return 'Sangat yakin';
    if (c > 0.8) return 'Yakin';
    if (c > 0.7) return 'Cukup yakin';
    if (c > 0.6) return 'Ragu';
    return 'Rendah';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _loadingView();
    if (!hasPermission) return _permissionView();

    final state = _state;
    final dir = _currentDirection;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      drawer: AppDrawer(services: widget.services),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.25),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Deteksi Mencontek',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          _liveBadge(),
          IconButton(
            tooltip: isFrontCamera ? 'Kamera depan' : 'Kamera belakang',
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          YOLOView(
            modelPath: _model,
            task: YOLOTask.detect,
            controller: controller,
            onResult: _onResult,
            showNativeUI: false,
            showOverlays: false,
            useGpu: true,
            cameraResolution: '720',
            onPerformanceMetrics: (m) {
              if (!mounted) return;
              setState(() {
                currentFPS = m.fps;
                processingTime = m.processingTimeMs;
              });
            },
          ),
          _faceGuide(),
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _infoPanel(),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: StatusBanner(state: state, direction: dir),
          ),
          if (debugMode) Positioned(bottom: 120, left: 16, right: 16, child: _debugPanel()),
          Positioned(
            bottom: 120,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => debugMode = !debugMode),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: debugMode ? AppColors.danger : Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bug_report, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 10),
            const SizedBox(width: 4),
            Text('${currentFPS.toStringAsFixed(0)} FPS',
                style: TextStyle(
                    color: currentFPS > 20 ? AppColors.safe : AppColors.warning,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _faceGuide() {
    final active = results.isNotEmpty && _topConfidence > _settings.confidenceThreshold;
    return Center(
      child: Container(
        width: 240,
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(
            color: active
                ? AppColors.forConfidence(_topConfidence)
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(120),
        ),
      ),
    );
  }

  Widget _infoPanel() {
    final hasResult = results.isNotEmpty && _topConfidence > _settings.confidenceThreshold;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.adjust, color: AppColors.textSecondary, size: 14),
              SizedBox(width: 6),
              Text('Mode: Deteksi Arah Pandang',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (hasResult) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_currentDirection.icon, color: _currentDirection.color, size: 24),
                const SizedBox(width: 8),
                Text(_currentDirection.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _topConfidence,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(AppColors.forConfidence(_topConfidence)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_confidenceLabel(_topConfidence)} · ${(_topConfidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: AppColors.forConfidence(_topConfidence), fontSize: 13),
            ),
          ] else
            const Text('Arahkan wajah ke kamera',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _debugPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DEBUG',
              style: TextStyle(
                  color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Model: $_model',
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(
            'Frame: $frameCount · Stabil: '
            '${_sameClassCount >= _settings.stabilityFrames ? "ya" : "tidak"} · '
            '${processingTime.toStringAsFixed(0)}ms',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          ...results.take(3).map((r) => Text(
                '${r.className}: ${(r.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              )),
        ],
      ),
    );
  }

  Widget _loadingView() => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Memuat kamera...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

  Widget _permissionView() => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography, size: 72, color: AppColors.textSecondary),
                const SizedBox(height: 24),
                const Text('Akses Kamera Diperlukan',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Aplikasi membutuhkan kamera untuk memantau arah pandang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Berikan Akses Kamera'),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}
