import '../constants/app_constants.dart';
import '../utils/mala_calculator.dart';

/// Everything the ongoing notification and the home screen widget need to
/// render, in one immutable value.
///
/// Both surfaces are driven from a single snapshot so they can never disagree:
/// whoever changes the count builds one of these and pushes it to both.
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.dateKey,
    required this.count,
    required this.goalCount,
    required this.streak,
    required this.totalCount,
  });

  /// `yyyy-MM-dd` of the day these numbers describe. Consumers that outlive a
  /// midnight rollover (the widget in particular) compare this against today to
  /// notice they're showing stale data.
  final String dateKey;

  final int count;
  final int goalCount;
  final int streak;
  final int totalCount;

  bool get hasGoal => goalCount > 0;

  bool get goalComplete => hasGoal && count >= goalCount;

  /// Counts still to go, floored at zero (overshooting a goal is allowed).
  int get remaining => hasGoal ? (goalCount - count).clamp(0, goalCount) : 0;

  /// 0..1, clamped — feeds both the notification and widget progress bars.
  double get progress =>
      hasGoal ? (count / goalCount).clamp(0.0, 1.0).toDouble() : 0.0;

  int get percent => (progress * 100).round();

  MalaBreakdown get breakdown => MalaCalculator.breakdown(count);

  int get goalMala => goalCount ~/ AppConstants.countsPerMala;

  ProgressSnapshot copyWith({int? count, int? goalCount, int? streak}) =>
      ProgressSnapshot(
        dateKey: dateKey,
        count: count ?? this.count,
        goalCount: goalCount ?? this.goalCount,
        streak: streak ?? this.streak,
        totalCount: totalCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressSnapshot &&
          other.dateKey == dateKey &&
          other.count == count &&
          other.goalCount == goalCount &&
          other.streak == streak &&
          other.totalCount == totalCount;

  @override
  int get hashCode => Object.hash(dateKey, count, goalCount, streak, totalCount);

  @override
  String toString() =>
      'ProgressSnapshot($dateKey, $count/$goalCount, streak $streak)';
}
