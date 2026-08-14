import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake while the user is counting.
///
/// A mala is 108 counts and a serious session is several of them, all driven by
/// the volume buttons or a single repeated tap — neither of which resets the
/// system idle timer reliably, so the phone happily locks mid-chant.
///
/// The lock is *reference counted* rather than a plain on/off flag, because more
/// than one screen wants it at once: the dashboard holds it while it is in the
/// foreground, and Focus mode holds it on top of that. Without counting, the
/// dashboard's idle timeout would release the lock out from under an active
/// Focus session. The screen stays awake while at least one holder remains.
///
/// Every call degrades to a no-op on platforms without a wakelock rather than
/// throwing, so callers never have to branch on the platform.
class WakelockService {
  WakelockService();

  final Set<Object> _holders = <Object>{};
  bool _applied = false;

  /// Whether the screen is currently being held awake.
  bool get isEnabled => _applied;

  /// Hold the screen awake on behalf of [owner]. Calling this repeatedly with
  /// the same owner is harmless — it's one hold, not many.
  Future<void> acquire(Object owner) async {
    if (!_holders.add(owner)) return;
    await _sync();
  }

  /// Drop [owner]'s hold. The screen only goes back to its normal timeout once
  /// every other holder has released too.
  Future<void> release(Object owner) async {
    if (!_holders.remove(owner)) return;
    await _sync();
  }

  Future<void> _sync() async {
    final wanted = _holders.isNotEmpty;
    if (wanted == _applied) return;
    try {
      await WakelockPlus.toggle(enable: wanted);
      _applied = wanted;
    } catch (e) {
      debugPrint('WakelockService failed to set $wanted: $e');
    }
  }

  void dispose() {
    _holders.clear();
    _sync();
  }
}
