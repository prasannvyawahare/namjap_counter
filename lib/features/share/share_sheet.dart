import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_helpers.dart';
import '../../providers/counter_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_controller.dart';
import '../../providers/statistics_providers.dart';

/// Bottom sheet offering daily / weekly / monthly WhatsApp share messages.
class ShareSheet extends ConsumerWidget {
  const ShareSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => const ShareSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final counter = ref.watch(counterProvider);
    final stats = ref.watch(statisticsProvider);
    final shareService = ref.read(shareServiceProvider);
    final now = DateTime.now();

    Future<void> shareAndClose(String message) async {
      Navigator.of(context).pop();
      await shareService.shareText(message);
    }

    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.share, size: 18),
        onTap: onTap,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Share your progress',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            option(
              icon: Icons.today,
              title: 'Today',
              subtitle:
                  '${counter.todayCount} counts · ${counter.todayBreakdown.formatted}',
              onTap: () => shareAndClose(
                shareService.dailyMessage(
                  name: settings.name,
                  count: counter.todayCount,
                  goalMala: settings.dailyGoalMala,
                ),
              ),
            ),
            option(
              icon: Icons.calendar_view_week,
              title: 'This Week',
              subtitle:
                  '${stats.thisWeek.count} counts · ${stats.thisWeek.mala} Mala',
              onTap: () => shareAndClose(
                shareService.weeklyMessage(
                  name: settings.name,
                  totalCount: stats.thisWeek.count,
                ),
              ),
            ),
            option(
              icon: Icons.calendar_month,
              title: 'This Month',
              subtitle:
                  '${stats.thisMonth.count} counts · ${stats.thisMonth.mala} Mala',
              onTap: () => shareAndClose(
                shareService.monthlyMessage(
                  monthName: DateHelpers.monthLabel(now).split(' ').first,
                  totalCount: stats.thisMonth.count,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
