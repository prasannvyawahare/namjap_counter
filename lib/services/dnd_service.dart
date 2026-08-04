import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to the platform Do Not Disturb (interruption filter) controls.
///
/// Only Android exposes a public API for toggling system DND, and even there it
/// requires the user to grant "Do Not Disturb access" to the app once. Every
/// method degrades gracefully to a no-op / `false` on unsupported platforms so
/// callers never have to branch on the platform themselves.
///
/// Silence is *held*, not switched, for the same reason the screen lock is:
/// the dashboard wants it while the preference is on, and Focus mode wants it
/// for the length of a session regardless. A plain on/off flag let whichever
/// screen finished last decide, so leaving Focus with the preference off could
/// walk away leaving the phone silenced with nothing in the UI admitting it.
/// The system is restored once the last holder lets go.
class DndService {
  DndService();

  static const MethodChannel _channel = MethodChannel('namjap/dnd');

  final Set<Object> _holders = <Object>{};

  /// Whether *we* are the reason interruptions are currently silenced.
  bool _holding = false;

  /// Whether the user already had the phone silenced when we first asked. If
  /// so we leave it that way on the way out — turning off a Do Not Disturb the
  /// user set themselves would be the app overreaching.
  bool _silencedBeforeUs = false;

  /// Serialises the platform calls: acquire/release are routinely fired without
  /// being awaited (from `dispose`, for one), and two overlapping syncs could
  /// otherwise both read the old state and fight.
  Future<void> _queue = Future<void>.value();

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Whether anything is still asking for silence.
  bool get isHeld => _holding;

  /// Completes once every pending acquire/release has reached the system.
  /// Callers that want to *show* the resulting state have to wait for this,
  /// or they'll read the filter back before it has been changed.
  Future<void> get settled => _queue;

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

  /// Whether the system is silencing interruptions right now, whoever asked
  /// for it. This is the truth the Settings screen shows, rather than the
  /// stored preference, which says only what the app intends.
  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
      // Deliberately broad, as above.
    } catch (e) {
      debugPrint('DndService.isEnabled failed: $e');
      return false;
    }
  }

  /// Ask for silence on behalf of [owner]. Repeat calls from the same owner are
  /// one hold, not many.
  Future<void> acquire(Object owner) {
    if (!_holders.add(owner)) return Future<void>.value();
    return _sync();
  }

  /// Drop [owner]'s hold. Interruptions come back once everyone has let go.
  Future<void> release(Object owner) {
    if (!_holders.remove(owner)) return Future<void>.value();
    return _sync();
  }

  /// Hand the phone back unconditionally, whoever was holding it.
  Future<void> releaseAll() {
    if (_holders.isEmpty) return Future<void>.value();
    _holders.clear();
    return _sync();
  }

  Future<void> _sync() => _queue = _queue.then((_) => _apply());

  Future<void> _apply() async {
    final wanted = _holders.isNotEmpty;
    if (wanted == _holding) return;

    if (wanted) {
      _silencedBeforeUs = await isEnabled();
      // Already quiet by the user's own doing: count it as held so the last
      // release knows not to undo something that was never ours.
      _holding = _silencedBeforeUs || await _setFilter(true);
    } else {
      if (!_silencedBeforeUs) await _setFilter(false);
      _holding = false;
      _silencedBeforeUs = false;
    }
  }

  /// Turns the system interruption filter on or off. Returns whether the
  /// change was actually applied (false if unsupported or permission is
  /// missing).
  Future<bool> _setFilter(bool enabled) async {
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
