import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/mala_calculator.dart';
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
      if (mounted) _syncActiveDate();
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

  /// Called on start-up and whenever the app resumes to honour the automatic
  /// midnight reset. Because each day is its own record, moving the active date
  /// forward is all that's needed — yesterday's data is already in history.
  void _syncActiveDate() {
    final settings = _ref.read(settingsProvider);
    final now = DateTime.now();
    if (settings.autoReset && !DateHelpers.isSameDay(state.activeDate, now)) {
      state = state.copyWith(
        activeDate: now,
        todayCount: _repo.countFor(now),
        totalCount: _repo.totalCount(),
      );
    }
    // Keep the persisted pointer current.
    _ref
        .read(settingsProvider.notifier)
        .setActiveDate(DateHelpers.key(state.activeDate));
  }

  /// Invoked from the app lifecycle observer.
  void onResume() => _syncActiveDate();

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
  }

  void _bump() => revision.value++;

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
