import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/mala_progress_bar.dart';

/// The large "Today's Count" hero card shown at the top of the dashboard.
class CounterHeroCard extends StatelessWidget {
  const CounterHeroCard({
    super.key,
    required this.count,
    required this.malaText,
    required this.goalCount,
    required this.progress,
  });

  final int count;
  final String malaText;
  final int goalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Text(
            "Today's Count",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: ShaderMask(
              key: ValueKey<int>(count),
              shaderCallback: (bounds) => kSaffronGradient.createShader(bounds),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 88,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              malaText,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          MalaProgressBar(value: progress),
          const SizedBox(height: 8),
          Text(
            goalCount > 0 ? '$count / $goalCount' : '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
