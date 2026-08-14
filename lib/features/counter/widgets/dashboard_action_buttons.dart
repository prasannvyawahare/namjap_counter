import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The circular minus / plus counting buttons plus the volume-button hint.
class DashboardActionButtons extends StatelessWidget {
  const DashboardActionButtons({
    super.key,
    required this.onIncrement,
    required this.onDecrement,
  });

  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.remove,
          color: AppTheme.deepOrange,
          onTap: onDecrement,
        ),
        const _VolumeHint(),
        _RoundButton(
          icon: Icons.add,
          color: const Color(0xFF26A69A),
          onTap: onIncrement,
          large: true,
        ),
      ],
    );
  }
}

class _VolumeHint extends StatelessWidget {
  const _VolumeHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: 6),
        Text(
          'Use volume buttons',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool large;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.9 : 1);

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 76.0 : 64.0;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: widget.large ? 36 : 30,
          ),
        ),
      ),
    );
  }
}
