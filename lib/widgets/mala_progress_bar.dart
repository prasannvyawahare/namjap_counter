import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// An animated saffron progress bar used for the daily goal.
class MalaProgressBar extends StatelessWidget {
  const MalaProgressBar({
    super.key,
    required this.value,
    this.height = 10,
  });

  /// Progress in the range 0..1.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: height,
              width: constraints.maxWidth * clamped,
              decoration: BoxDecoration(
                gradient: kSaffronGradient,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ],
        );
      },
    );
  }
}
