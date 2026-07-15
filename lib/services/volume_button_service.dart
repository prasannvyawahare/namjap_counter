import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Listens to the hardware volume buttons and reports them as +1 / -1 events.
///
/// On Android the volume keys are intercepted natively in `MainActivity`, and
/// on iOS in `VolumeButtonHandler` (both over the `namjap/volume_buttons`
/// [EventChannel]). The native side consumes the presses and keeps the media
/// volume parked, so the system slider never appears — every press becomes a
/// clean count.
///
/// On other platforms we fall back to observing the media volume: park it at a
/// mid "anchor" value with the system UI hidden, translate any nudge into a
/// count, then snap back to the anchor so there is headroom in both directions.
class VolumeButtonService {
  VolumeButtonService();

  static const EventChannel _channel = EventChannel('namjap/volume_buttons');

  static const double _anchor = 0.5;
  static const double _threshold = 0.005;

  StreamSubscription<dynamic>? _subscription;
  bool _restoring = false;
  bool _active = false;

  VoidCallback? _onUp;
  VoidCallback? _onDown;

  bool get isActive => _active;

  bool get _useNative =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> start({
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) async {
    _onUp = onUp;
    _onDown = onDown;
    if (_active) return;
    _active = true;

    if (_useNative) {
      try {
        _subscription = _channel.receiveBroadcastStream().listen(
          (event) {
            if (!_active) return;
            if (event == 'up') {
              _onUp?.call();
            } else if (event == 'down') {
              _onDown?.call();
            }
          },
          onError: (Object e) =>
              debugPrint('VolumeButtonService native stream error: $e'),
        );
      } catch (e) {
        debugPrint('VolumeButtonService failed to start (native): $e');
        _active = false;
      }
      return;
    }

    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await _resetToAnchor();
      _subscription = FlutterVolumeController.addListener(
        _handleVolume,
        emitOnStart: false,
      );
    } catch (e) {
      // On unsupported platforms just leave the on-screen buttons working.
      debugPrint('VolumeButtonService failed to start: $e');
      _active = false;
    }
  }

  Future<void> _handleVolume(double volume) async {
    if (!_active || _restoring) return;

    final delta = volume - _anchor;
    if (delta.abs() < _threshold) return;

    if (delta > 0) {
      _onUp?.call();
    } else {
      _onDown?.call();
    }
    await _resetToAnchor();
  }

  Future<void> _resetToAnchor() async {
    _restoring = true;
    try {
      // showSystemUI is already globally disabled via updateShowSystemUI(false).
      await FlutterVolumeController.setVolume(_anchor);
    } catch (_) {
      // ignore
    } finally {
      // Give the platform a beat to emit the programmatic change before we
      // start reacting to real presses again.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      _restoring = false;
    }
  }

  Future<void> stop() async {
    _active = false;
    await _subscription?.cancel();
    _subscription = null;
    if (_useNative) return;
    try {
      FlutterVolumeController.removeListener();
      await FlutterVolumeController.updateShowSystemUI(true);
    } catch (_) {
      // ignore
    }
  }

  void dispose() {
    stop();
  }
}
