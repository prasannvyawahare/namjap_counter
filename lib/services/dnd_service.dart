import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to the platform Do Not Disturb (interruption filter) controls.
///
/// Only Android exposes a public API for toggling system DND, and even there it
/// requires the user to grant "Do Not Disturb access" to the app once. Every
/// method degrades gracefully to a no-op / `false` on unsupported platforms so
/// callers never have to branch on the platform themselves.
class DndService {
  DndService();

  static const MethodChannel _channel = MethodChannel('namjap/dnd');

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Whether the user has granted notification-policy access. Without it we
  /// cannot change the interruption filter, so the UI must send the user to
  /// system settings first via [openPolicySettings].
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
      // Deliberately broad: a build without the native handler registered
      // throws MissingPluginException, which is not a PlatformException and
      // would otherwise escape as an unhandled error mid-chant.
    } catch (e) {
      debugPrint('DndService.hasPermission failed: $e');
      return false;
    }
  }

  /// Opens the system screen where the user grants DND access to this app.
  Future<void> openPolicySettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openPolicySettings');
      // Deliberately broad: a build without the native handler registered
      // throws MissingPluginException, which is not a PlatformException and
      // would otherwise escape as an unhandled error mid-chant.
    } catch (e) {
      debugPrint('DndService.openPolicySettings failed: $e');
    }
  }

  /// Turns system Do Not Disturb on or off. Returns whether the change was
  /// actually applied (false if unsupported or permission is missing).
  Future<bool> setEnabled(bool enabled) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('setEnabled', {
            'enabled': enabled,
          }) ??
          false;
      // Deliberately broad: a build without the native handler registered
      // throws MissingPluginException, which is not a PlatformException and
      // would otherwise escape as an unhandled error mid-chant.
    } catch (e) {
      debugPrint('DndService.setEnabled failed: $e');
      return false;
    }
  }
}
