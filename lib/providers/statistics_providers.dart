import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/mala_calculator.dart';
import '../storage/models/daily_record.dart';
import 'counter_controller.dart';
import 'service_providers.dart';

/// A count + its Mala breakdown, with a label for display.
class StatEntry {
  const StatEntry({required this.label, required this.count});

  final String label;
  final int count;

  MalaBreakdown get breakdown => MalaCalculator.breakdown(count);
  int get mala => breakdown.mala;
}

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.today,
    required this.yesterday,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.lifetime,
  });

  final StatEntry today;
  final StatEntry yesterday;
  final StatEntry thisWeek;
  final StatEntry thisMonth;
  final StatEntry thisYear;
  final StatEntry lifetime;

  List<StatEntry> get all => [
    today,
    yesterday,
    thisWeek,
    thisMonth,
    thisYear,
    lifetime,
  ];
}

/// Aggregated statistics. Recomputed whenever the counter state changes.
final statisticsProvider = Provider<StatisticsSnapshot>((ref) {
  // Depend on counter state so any mutation refreshes these numbers.
  ref.watch(counterProvider);
  final repo = ref.watch(repositoryProvider);
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  return StatisticsSnapshot(
    today: StatEntry(label: 'Today', count: repo.countFor(now)),
    yesterday: StatEntry(label: 'Yesterday', count: repo.countFor(yesterday)),
    thisWeek: StatEntry(
      label: 'This Week',
      count: repo.countInRange((d) => DateHelpers.isInWeek(d, now)),
    ),
    thisMonth: StatEntry(
      label: 'This Month',
      count: repo.countInRange((d) => DateHelpers.isInMonth(d, now)),
    ),
    thisYear: StatEntry(
      label: 'This Year',
      count: repo.countInRange((d) => DateHelpers.isInYear(d, now)),
    ),
    lifetime: StatEntry(label: 'Lifetime', count: repo.totalCount()),
  );
});

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class PeriodSummary {
  const PeriodSummary({
    required this.label,
    required this.count,
    required this.days,
  });

  final String label;
  final int count;
  final int days;

  MalaBreakdown get breakdown => MalaCalculator.breakdown(count);
  int get mala => breakdown.mala;
  int get remaining => breakdown.remaining;
}

class HistorySnapshot {
  const HistorySnapshot({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.totalCount,
    required this.averageCountPerDay,
  });

  final List<DailyRecord> daily;
  final List<PeriodSummary> weekly;
  final List<PeriodSummary> monthly;
  final List<PeriodSummary> yearly;
  final int totalCount;
  final double averageCountPerDay;

  int get totalMala => MalaCalculator.malaCount(totalCount);
  double get averageMalaPerDay => averageCountPerDay / 108;
  int get activeDays => daily.length;
}

final historyProvider = Provider<HistorySnapshot>((ref) {
  ref.watch(counterProvider);
  final repo = ref.watch(repositoryProvider);
  final records = repo.allRecords(); // newest first, count > 0

  final weekly = <String, _Bucket>{};
  final monthly = <String, _Bucket>{};
  final yearly = <String, _Bucket>{};

  for (final r in records) {
    final dt = r.dateTime;
    if (dt == null) continue;

    final weekStart = DateHelpers.startOfWeek(dt);
    weekly
        .putIfAbsent(
          DateHelpers.key(weekStart),
          () => _Bucket(
            'Week of ${DateHelpers.shortLabel(weekStart)}',
            DateHelpers.key(weekStart),
          ),
        )
        .add(r.count);

    monthly
        .putIfAbsent(
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}',
          () => _Bucket(
            DateHelpers.monthLabel(dt),
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}',
          ),
        )
        .add(r.count);

    yearly
        .putIfAbsent('${dt.year}', () => _Bucket('${dt.year}', '${dt.year}'))
        .add(r.count);
  }

  final total = repo.totalCount();
  final activeDays = records.length;

  return HistorySnapshot(
    daily: records,
    weekly: _sortedSummaries(weekly),
    monthly: _sortedSummaries(monthly),
    yearly: _sortedSummaries(yearly),
    totalCount: total,
    averageCountPerDay: activeDays == 0 ? 0 : total / activeDays,
  );
});

List<PeriodSummary> _sortedSummaries(Map<String, _Bucket> map) {
  final entries = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return entries
      .map(
        (e) => PeriodSummary(
          label: e.value.label,
          count: e.value.count,
          days: e.value.days,
        ),
      )
      .toList();
}

class _Bucket {
  _Bucket(this.label, [this.sortKey = '']);
  final String label;
  final String sortKey;
  int count = 0;
  int days = 0;
  void add(int c) {
    count += c;
    days++;
  }
}
