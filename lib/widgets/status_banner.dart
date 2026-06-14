import 'package:flutter/material.dart';

import '../models/gaze_direction.dart';
import '../theme/app_theme.dart';

enum DetectionState { noFace, honest, cheating }

/// Banner status besar di bagian bawah layar deteksi.
///
/// Pengganti emoji lama (👤 😁 ⚠️) dengan Material Icons + warna yang jelas.
class StatusBanner extends StatelessWidget {
  final DetectionState state;
  final GazeDirection direction;

  const StatusBanner({super.key, required this.state, required this.direction});

  Color get _color {
    switch (state) {
      case DetectionState.noFace:
        return AppColors.neutral;
      case DetectionState.honest:
        return AppColors.safe;
      case DetectionState.cheating:
        return AppColors.danger;
    }
  }

  IconData get _icon {
    switch (state) {
      case DetectionState.noFace:
        return Icons.person_search;
      case DetectionState.honest:
        return Icons.verified_user;
      case DetectionState.cheating:
        return Icons.gpp_maybe;
    }
  }

  String get _title {
    switch (state) {
      case DetectionState.noFace:
        return 'Wajah Tidak Terdeteksi';
      case DetectionState.honest:
        return 'Tetap Jujur';
      case DetectionState.cheating:
        return 'Terdeteksi Mencontek';
    }
  }

  String get _subtitle {
    switch (state) {
      case DetectionState.noFace:
        return 'Arahkan wajah ke dalam bingkai';
      case DetectionState.honest:
        return 'Pandangan lurus ke depan';
      case DetectionState.cheating:
        return direction.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
