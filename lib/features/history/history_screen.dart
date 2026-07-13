import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_helpers.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_controller.dart';
import '../../providers/statistics_providers.dart';
import '../../storage/models/daily_record.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_tile.dart';
import '../statistics/statistics_screen.dart';

enum _HistoryView { daily, weekly, monthly, yearly }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryView _view = _HistoryView.daily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Share summary',
            icon: const Icon(Icons.share),
            onPressed: () => _shareSummary(stats),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.calendar_today,
                  value: '${stats.thisWeek.count}',
                  caption: 'This Week',
                  subtitle: '${stats.thisWeek.mala} Mala',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.calendar_month,
                  value: '${stats.thisMonth.count}',
                  caption: 'This Month',
                  subtitle: '${stats.thisMonth.mala} Mala',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.trending_up,
                  value: history.averageCountPerDay.round().toString(),
                  caption: 'Avg/Day',
                  subtitle:
                      '${history.averageMalaPerDay.toStringAsFixed(1)} Mala',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TotalsCard(history: history),
          const SizedBox(height: 20),
          SegmentedButton<_HistoryView>(
            segments: const [
              ButtonSegment(value: _HistoryView.daily, label: Text('Daily')),
              ButtonSegment(value: _HistoryView.weekly, label: Text('Weekly')),
              ButtonSegment(
                  value: _HistoryView.monthly, label: Text('Monthly')),
              ButtonSegment(value: _HistoryView.yearly, label: Text('Yearly')),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            _titleForView(),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._buildList(history),
        ],
      ),
    );
  }

  String _titleForView() {
    switch (_view) {
      case _HistoryView.daily:
        return 'Daily Records';
      case _HistoryView.weekly:
        return 'Weekly Summary';
      case _HistoryView.monthly:
        return 'Monthly Summary';
      case _HistoryView.yearly:
        return 'Yearly Summary';
    }
  }

  List<Widget> _buildList(HistorySnapshot history) {
    if (_view == _HistoryView.daily) {
      if (history.daily.isEmpty) return [const _EmptyHistory()];
      return history.daily
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DailyRecordTile(record: r),
              ))
          .toList();
    }

    final summaries = switch (_view) {
      _HistoryView.weekly => history.weekly,
      _HistoryView.monthly => history.monthly,
      _HistoryView.yearly => history.yearly,
      _HistoryView.daily => const <PeriodSummary>[],
    };
    if (summaries.isEmpty) return [const _EmptyHistory()];
    return summaries
        .map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SummaryTile(summary: s),
            ))
        .toList();
  }

  void _shareSummary(StatisticsSnapshot stats) {
    final name = ref.read(settingsProvider).name;
    final message = ref.read(shareServiceProvider).weeklyMessage(
          name: name,
          totalCount: stats.thisWeek.count,
        );
    ref.read(shareServiceProvider).shareText(message);
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.history});
  final HistorySnapshot history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
            ],
          ),
        );
    return AppCard(
      child: Row(
        children: [
          cell('Total Count', '${history.totalCount}'),
          cell('Total Mala', '${history.totalMala}'),
          cell('Active Days', '${history.activeDays}'),
        ],
      ),
    );
  }
}

class _DailyRecordTile extends StatelessWidget {
  const _DailyRecordTile({required this.record});
  final DailyRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = record.dateTime;
    final b = record.breakdown;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dt == null ? record.date : DateHelpers.shortLabel(dt),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (dt != null)
                Text(
                  DateHelpers.monthShortLabel(dt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${record.count} counts',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
              Text('${b.mala} Mala · ${b.remaining} remaining',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${summary.days} active day(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${summary.count} counts',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
              Text('${summary.mala} Mala · ${summary.remaining} remaining',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.history,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No history yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
          const SizedBox(height: 6),
          Text('Start counting to build your history',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              )),
        ],
      ),
    );
  }
}
