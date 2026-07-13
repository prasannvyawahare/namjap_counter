import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Small wrapper around haptic feedback so callers don't have to worry about
/// whether the device supports a custom vibrator.
class HapticService {
  bool _hasVibrator = false;
  bool _checked = false;

  Future<void> _ensureChecked() async {
    if (_checked) return;
    _checked = true;
    try {
      _hasVibrator = await Vibration.hasVibrator();
    } catch (_) {
      _hasVibrator = false;
    }
  }

  /// A light tap for a successful count.
  Future<void> tick() async {
    await _ensureChecked();
    try {
      if (_hasVibrator) {
        await Vibration.vibrate(duration: 20, amplitude: 128);
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Never let feedback failures break counting.
      HapticFeedback.selectionClick();
    }
  }

  /// A stronger celebratory buzz, e.g. when a Mala or the daily goal completes.
  Future<void> celebrate() async {
    await _ensureChecked();
    try {
      if (_hasVibrator) {
        await Vibration.vibrate(pattern: [0, 60, 40, 120], intensities: [0, 200, 0, 255]);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }
}
