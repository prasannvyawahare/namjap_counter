import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/counter_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_controller.dart';
import '../../widgets/app_card.dart';
import '../../widgets/mala_progress_bar.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_sheet.dart';
import 'widgets/counter_hero_card.dart';
import 'widgets/dashboard_action_buttons.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  late final ConfettiController _confetti;
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _quoteIndex = DateTime.now().day % AppConstants.quotes.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVolume();
      _applyDnd(true);
      ref
          .read(counterProvider.notifier)
          .celebration
          .addListener(_onCelebrationChanged);
    });
  }

  void _onCelebrationChanged() {
    _onCelebration(ref.read(counterProvider.notifier).celebration.value);
  }

  Future<void> _startVolume() async {
    final service = ref.read(volumeButtonServiceProvider);
    await service.start(
      onUp: () => ref.read(counterProvider.notifier).increment(),
      onDown: () => ref.read(counterProvider.notifier).decrement(),
    );
  }

  /// Mirror the user's "Do Not Disturb while counting" preference onto the
  /// system: silence calls/notifications while the app is in the foreground,
  /// restore them when it leaves. A no-op unless the preference is on and the
  /// platform (Android) supports it with permission granted.
  Future<void> _applyDnd(bool enable) async {
    final wants = ref.read(settingsProvider).dndWhileCounting;
    if (!wants) return;
    await ref.read(dndServiceProvider).setEnabled(enable);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(counterProvider.notifier).onResume();
      _startVolume();
      _applyDnd(true);
    } else if (state == AppLifecycleState.paused) {
      ref.read(volumeButtonServiceProvider).stop();
      _applyDnd(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref
        .read(counterProvider.notifier)
        .celebration
        .removeListener(_onCelebrationChanged);
    ref.read(volumeButtonServiceProvider).stop();
    // Best-effort: hand DND back to the system as we tear down.
    ref.read(dndServiceProvider).setEnabled(false);
    _confetti.dispose();
    super.dispose();
  }

  void _onCelebration(CelebrationKind kind) {
    if (kind == CelebrationKind.goal) {
      _confetti.play();
    }
    if (kind != CelebrationKind.none) {
      ref.read(counterProvider.notifier).clearCelebration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final counter = ref.watch(counterProvider);
    final controller = ref.read(counterProvider.notifier);

    final goalCount = settings.dailyGoalCount;
    final progress = goalCount > 0 ? counter.todayCount / goalCount : 0.0;

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth - 10;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: contentWidth,
                    height: constraints.maxHeight,
                    // BoxFit.fill with matching widths scales only the vertical
                    // axis, so the content keeps its full width (just the 10px
                    // side padding) while shrinking to fit the height.
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: contentWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Header(name: settings.name),
                              const SizedBox(height: 20),
                              CounterHeroCard(
                                count: counter.todayCount,
                                malaText: counter.todayBreakdown.formatted,
                                goalCount: goalCount,
                                progress: progress,
                              ),
                              const SizedBox(height: 16),
                              _TotalCard(
                                totalCount: counter.totalCount,
                                totalMala: counter.totalBreakdown.formatted,
                              ),
                              const SizedBox(height: 16),
                              _GoalCard(
                                todayCount: counter.todayCount,
                                goalCount: goalCount,
                              ),
                              const SizedBox(height: 20),
                              DashboardActionButtons(
                                onIncrement: controller.increment,
                                onDecrement: controller.decrement,
                              ),
                              const SizedBox(height: 24),
                              _BottomActions(
                                onHistory: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const HistoryScreen(),
                                  ),
                                ),
                                onShare: () => ShareSheet.show(context),
                                onReset: _confirmReset,
                              ),
                              const SizedBox(height: 20),
                              _QuoteCard(
                                quote: AppConstants.quotes[_quoteIndex],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
              gravity: 0.25,
              colors: const [
                AppTheme.saffron,
                AppTheme.deepOrange,
                Colors.amber,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final counter = ref.read(counterProvider);
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset today's counter?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogRow('Current Count', '${counter.todayCount}'),
            const SizedBox(height: 6),
            _DialogRow('Current Mala', counter.todayBreakdown.formatted),
            const SizedBox(height: 16),
            Text(
              'This will clear today and keep past days in your History.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(counterProvider.notifier).reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today\'s counter has been reset.')),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final display = name.trim().isEmpty ? 'Devotee' : name.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateHelpers.greeting(now)},',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                display,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateHelpers.longLabel(now),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalCount, required this.totalMala});
  final int totalCount;
  final String totalMala;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(Icons.insights, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Count',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalCount',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Mala · $totalMala',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.todayCount, required this.goalCount});
  final int todayCount;
  final int goalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (goalCount <= 0) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('No daily goal set')),
          ],
        ),
      );
    }
    final goalMala = goalCount ~/ AppConstants.countsPerMala;
    final doneMala = todayCount ~/ AppConstants.countsPerMala;
    final progress = todayCount / goalCount;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Daily Goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress.clamp(0, 1) * 100).round()}%',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MalaProgressBar(value: progress),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$doneMala / $goalMala Mala',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '$todayCount / $goalCount Counts',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onHistory,
    required this.onShare,
    required this.onReset,
  });

  final VoidCallback onHistory;
  final VoidCallback onShare;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.history,
            label: 'History',
            onTap: onHistory,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.refresh,
            label: 'Reset',
            onTap: onReset,
            filled: true,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      gradient: filled ? kSaffronGradient : null,
      child: Column(
        children: [
          Icon(icon, color: filled ? Colors.white : theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
