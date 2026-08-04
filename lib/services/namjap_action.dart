import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The counting commands that can arrive from outside the Flutter UI — a
/// notification action button, a home screen widget button, or the system
/// telling us the date rolled over.
enum NamjapAction {
  increment,
  decrement,

  /// Re-read storage and repaint the notification and widget without changing
  /// anything. Used for midnight rollover, reboot and settings changes.
  refresh;

  /// Ids used for the `flutter_local_notifications` action buttons. They travel
  /// through the OS, so they're spelled out rather than derived from [name].
  static const String incrementNotificationId = 'namjap.increment';
  static const String decrementNotificationId = 'namjap.decrement';
  static const String openNotificationId = 'namjap.open';

  /// Uris used for the home screen widget buttons.
  static const String scheme = 'namjap';

  static NamjapAction? fromNotificationId(String? id) => switch (id) {
    incrementNotificationId => NamjapAction.increment,
    decrementNotificationId => NamjapAction.decrement,
    _ => null,
  };

  /// Widget buttons broadcast `namjap://<host>`; anything unrecognised (an
  /// empty uri from a plain widget refresh, say) is treated as a repaint.
  static NamjapAction fromUri(Uri? uri) => switch (uri?.host) {
    'increment' => NamjapAction.increment,
    'decrement' => NamjapAction.decrement,
    _ => NamjapAction.refresh,
  };

  Uri get uri => Uri(scheme: scheme, host: name);
}

/// Lets a background isolate hand an action to the running app instead of
/// writing to storage itself.
///
/// Notification and widget taps always wake a *separate* Flutter isolate — the
/// plugins spin up their own engine even when the app is in the foreground. Two
/// isolates writing the same Hive boxes would diverge, so the background side
/// always offers the work to the main isolate first (via a port published under
/// [_portName]) and only falls back to touching storage when nobody answers,
/// which means the app isn't running.
class NamjapActionBridge {
  const NamjapActionBridge._();

  static const String _portName = 'namjap.action.bridge';

  static ReceivePort? _port;

  /// Publishes the main isolate as the owner of all counting. Safe to call
  /// more than once; the previous registration is replaced.
  static void host(void Function(NamjapAction action) onAction) {
    stopHosting();
    final port = ReceivePort();
    // A stale mapping survives a hot restart, so clear before claiming the name.
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen((message) {
      final action = NamjapAction.values
          .where((a) => a.name == message)
          .firstOrNull;
      if (action != null) onAction(action);
    });
    _port = port;
  }

  static void stopHosting() {
    if (_port == null) return;
    IsolateNameServer.removePortNameMapping(_portName);
    _port?.close();
    _port = null;
  }

  /// Forwards [action] to the running app. Returns false when there is no app
  /// to forward to, meaning the caller must apply the action itself.
  static bool offer(NamjapAction action) {
    final port = IsolateNameServer.lookupPortByName(_portName);
    if (port == null) return false;
    try {
      port.send(action.name);
      return true;
    } catch (e) {
      // The app died between the lookup and the send.
      debugPrint('NamjapActionBridge: hand-off failed, applying locally: $e');
      return false;
    }
  }
}
