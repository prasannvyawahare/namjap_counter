import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Asks how many Malas this sitting should run for before Focus mode starts.
///
/// Returns the target in Malas, `0` for an open-ended session, or `null` if the
/// sheet was dismissed without choosing (in which case Focus mode shouldn't
/// open at all).
class FocusTargetSheet extends StatefulWidget {
  const FocusTargetSheet({super.key, this.initialMala = 0});

  final int initialMala;

  static Future<int?> show(BuildContext context, {int initialMala = 0}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FocusTargetSheet(initialMala: initialMala),
    );
  }

  @override
  State<FocusTargetSheet> createState() => _FocusTargetSheetState();
}

class _FocusTargetSheetState extends State<FocusTargetSheet> {
  static const List<int> _choices = [0, 1, 3, 5, 11, 16];

  late int _selected = _choices.contains(widget.initialMala)
      ? widget.initialMala
      : 0;

  String _label(int mala) {
    if (mala == 0) return 'No limit';
    return '$mala Mala';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _selected * AppConstants.countsPerMala;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.self_improvement, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Focus session',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A quiet full-screen counter. Tap anywhere or use the volume '
              'keys — the screen stays awake and notifications stay quiet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Stop me at',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _choices.map((mala) {
                return ChoiceChip(
                  label: Text(_label(mala)),
                  selected: _selected == mala,
                  onSelected: (_) => setState(() => _selected = mala),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _selected == 0
                  ? 'Count freely — nothing will interrupt you.'
                  : "We'll chime and pause at $counts counts.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Begin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
