import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/mala_calculator.dart';
import '../services/namjap_action.dart';
import '../storage/namjap_repository.dart';
import 'service_providers.dart';
import 'settings_controller.dart';

/// Immutable snapshot of the counting state for the active day.
class CounterState {
  const CounterState({
    required this.todayCount,
    required this.totalCount,
    required this.activeDate,
  });

  final int todayCount;
  final int totalCount;
  final DateTime activeDate;

  MalaBreakdown get todayBreakdown => MalaCalculator.breakdown(todayCount);
  MalaBreakdown get totalBreakdown => MalaCalculator.breakdown(totalCount);

  CounterState copyWith({
    int? todayCount,
    int? totalCount,
    DateTime? activeDate,
  }) {
    return CounterState(
      todayCount: todayCount ?? this.todayCount,
      totalCount: totalCount ?? this.totalCount,
      activeDate: activeDate ?? this.activeDate,
    );
  }
}

/// A transient event other widgets can listen to in order to celebrate.
enum CelebrationKind { none, mala, goal }

class CounterController extends StateNotifier<CounterState> {
  CounterController(this._repo, this._ref) : super(_load(_repo, _ref)) {
    // Deferred by a microtask rather than called inline: _syncActiveDate writes
    // the active date back to settingsProvider, and modifying one provider
    // while another is still building is an error Riverpod asserts against.
    // The `mounted` guard covers a container torn down before the microtask
    // runs, which would otherwise read from a disposed provider.
    Future.microtask(() {
      if (mounted) {
        _syncActiveDate();
        _armMidnightTimer();
      }
    });
  }

  final NamjapRepository _repo;
  final Ref _ref;

  /// Bumped whenever the underlying data changes so history / statistics
  /// providers know to recompute.
  final revision = ValueNotifier<int>(0);

  /// The most recent celebration triggered by a count, consumed by the UI.
  final celebration = ValueNotifier<CelebrationKind>(CelebrationKind.none);

  static CounterState _load(NamjapRepository repo, Ref ref) {
    final now = DateTime.now();
    final settings = ref.read(settingsProvider);
    final activeKey = settings.activeDate;
    DateTime active;
    if (settings.autoReset || activeKey == null) {
      active = now;
    } else {
      active = DateHelpers.parseKey(activeKey) ?? now;
    }
    return CounterState(
      todayCount: repo.countFor(active),
      totalCount: repo.totalCount(),
      activeDate: active,
    );
  }

  Timer? _midnightTimer;

  /// Called on start-up and whenever the app resumes to honour the automatic
  /// midnight reset. Because each day is its own record, moving the active date
  /// forward is all that's needed — yesterday's data is already in history.
  ///
  /// [push] is only turned off by callers that are about to change the count
  /// anyway, so the notification and widget aren't repainted twice for one tap.
  void _syncActiveDate({bool push = true}) {
    final settings = _ref.read(settingsProvider);
    final now = DateTime.now();
    if (settings.autoReset && !DateHelpers.isSameDay(state.activeDate, now)) {
      state = state.copyWith(
        activeDate: now,
        todayCount: _repo.countFor(now),
        totalCount: _repo.totalCount(),
      );
      _bump();
    }
    // Keep the persisted pointer current.
    _ref
        .read(settingsProvider.notifier)
        .setActiveDate(DateHelpers.key(state.activeDate));
    if (push) _pushProgress();
  }

  /// Rolls the day over while the app is simply sitting open — otherwise a
  /// dashboard left running overnight would keep counting into yesterday. One
  /// timer per day costs nothing; the notification and widget are repainted as
  /// a side effect of [_syncActiveDate].
  void _armMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      _syncActiveDate();
      _armMidnightTimer();
    });
  }

  /// Invoked from the app lifecycle observer.
  void onResume() {
    _syncActiveDate();
    _armMidnightTimer();
  }

  /// Applies a +1 / -1 sent from the notification or the home screen widget
  /// while the app is alive.
  ///
  /// It goes through the ordinary [increment] / [decrement] path on purpose:
  /// storage, Riverpod, the dashboard, the notification and the widget all
  /// update exactly as if the button had been pressed on screen.
  Future<void> handleExternalAction(NamjapAction action) async {
    final counts = action != NamjapAction.refresh;
    _syncActiveDate(push: !counts);
    switch (action) {
      case NamjapAction.increment:
        await increment();
      case NamjapAction.decrement:
        // Already at zero: nothing is written, but the surfaces still need a
        // repaint so a pressed button never looks like it was ignored.
        if (state.todayCount <= 0) {
          _pushProgress();
        } else {
          await decrement();
        }
      case NamjapAction.refresh:
        break;
    }
  }

  Future<void> increment() async {
    final next = state.todayCount + 1;
    await _apply(next);
    _fireFeedback(next, isIncrement: true);
  }

  Future<void> decrement() async {
    if (state.todayCount <= 0) return;
    final next = state.todayCount - 1;
    await _apply(next);
    _feedbackTick();
  }

  Future<void> reset() async {
    await _apply(0);
    _bump();
  }

  Future<void> _apply(int next) async {
    await _repo.setCount(state.activeDate, next);
    state = state.copyWith(todayCount: next, totalCount: _repo.totalCount());
    _bump();
    _pushProgress();
  }

  void _bump() => revision.value++;

  bool _pushing = false;
  bool _pushQueued = false;

  /// Repaints the ongoing notification and the home screen widget from
  /// storage.
  ///
  /// Only one push runs at a time. A burst of counts — volume-button chanting
  /// is genuinely fast — collapses into a single trailing repaint instead of
  /// one platform round-trip per bead, so the shade always ends on the true
  /// count without waking the notification manager dozens of times a second.
  void _pushProgress() {
    if (_pushing) {
      _pushQueued = true;
      return;
    }
    _pushing = true;
    _pushQueued = false;
    final settings = _ref.read(settingsProvider);
    _ref
        .read(progressSyncProvider)
        .push(settings: settings)
        .catchError((Object e) {
          debugPrint('CounterController: progress push failed: $e');
          return _ref.read(progressSyncProvider).read(settings: settings);
        })
        .whenComplete(() {
          _pushing = false;
          if (_pushQueued && mounted) _pushProgress();
        });
  }

  void _fireFeedback(int newCount, {required bool isIncrement}) {
    final settings = _ref.read(settingsProvider);
    final haptic = _ref.read(hapticServiceProvider);

    final goal = settings.dailyGoalCount;
    final reachedGoal = isIncrement && goal > 0 && newCount == goal;
    final completedMala = isIncrement && newCount > 0 && newCount % 108 == 0;

    if (settings.vibrationEnabled) {
      if (reachedGoal || completedMala) {
        haptic.celebrate();
      } else {
        haptic.tick();
      }
    }

    if (reachedGoal) {
      celebration.value = CelebrationKind.goal;
    } else if (completedMala) {
      celebration.value = CelebrationKind.mala;
    }
  }

  void _feedbackTick() {
    final settings = _ref.read(settingsProvider);
    if (settings.vibrationEnabled) {
      _ref.read(hapticServiceProvider).tick();
    }
  }

  void clearCelebration() => celebration.value = CelebrationKind.none;

  @override
  void dispose() {
    _midnightTimer?.cancel();
    revision.dispose();
    celebration.dispose();
    super.dispose();
  }
}

final counterProvider = StateNotifierProvider<CounterController, CounterState>((
  ref,
) {
  return CounterController(ref.watch(repositoryProvider), ref);
});
