import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_controller.dart';
import '../../widgets/app_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController = TextEditingController(text: settings.name);
    _goalController = TextEditingController(
      text: settings.dailyGoalCount.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(settingsProvider.notifier);
    final goal =
        int.tryParse(_goalController.text.trim()) ??
        AppConstants.defaultDailyGoalCount;
    await controller.updateName(_nameController.text);
    await controller.updateGoalCount(goal);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    Navigator.of(context).maybePop();
  }

  Future<void> _onDndChanged(bool value) async {
    final dnd = ref.read(dndServiceProvider);
    final controller = ref.read(settingsProvider.notifier);

    if (value && !await dnd.hasPermission()) {
      if (!mounted) return;
      final grant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow Do Not Disturb access'),
          content: const Text(
            'To silence calls and notifications while you chant, Namjap needs '
            '"Do Not Disturb access". Open system settings to grant it — then '
            'come back and it will take effect the next time the app is open.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (grant == true) await dnd.openPolicySettings();
    }

    // Persist intent regardless — once access is granted it applies while the
    // app is in the foreground.
    await controller.setDndWhileCounting(value);
    await dnd.setEnabled(value);
  }

  Future<void> _onReminderChanged(bool value) async {
    final notif = ref.read(notificationServiceProvider);
    final controller = ref.read(settingsProvider.notifier);

    if (value) {
      final granted = await notif.requestPermission();
      await controller.setReminderEnabled(true);
      final s = ref.read(settingsProvider);
      await notif.scheduleDaily(s.reminderHour, s.reminderMinute);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enable notifications for Namjap in system settings to receive '
              'reminders.',
            ),
          ),
        );
      }
    } else {
      await controller.setReminderEnabled(false);
      await notif.cancelReminder();
    }
  }

  Future<void> _pickReminderTime() async {
    final s = ref.read(settingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (picked == null) return;
    await ref
        .read(settingsProvider.notifier)
        .setReminderTime(picked.hour, picked.minute);
    if (s.reminderEnabled) {
      await ref
          .read(notificationServiceProvider)
          .scheduleDaily(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final goalCount =
        int.tryParse(_goalController.text.trim()) ?? settings.dailyGoalCount;
    final goalMala = goalCount ~/ AppConstants.countsPerMala;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _sectionTitle(theme, 'Profile'),
          const SizedBox(height: 12),
          Text('Name', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Daily Goal'),
          const SizedBox(height: 12),
          Text('Target Count', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _goalController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '108'),
          ),
          const SizedBox(height: 6),
          Text(
            goalCount > 0
                ? 'Equals $goalMala Mala per day'
                : 'Set your daily target (0 to disable)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [1, 3, 5, 10, 16]
                .map(
                  (m) => ActionChip(
                    label: Text('$m Mala'),
                    onPressed: () => setState(
                      () => _goalController.text =
                          (m * AppConstants.countsPerMala).toString(),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Feedback'),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.music_note,
            iconColor: theme.colorScheme.primary,
            title: 'Sound',
            subtitle: 'Play sound on count',
            value: settings.soundEnabled,
            onChanged: ref.read(settingsProvider.notifier).setSound,
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.vibration,
            iconColor: theme.colorScheme.secondary,
            title: 'Vibration',
            subtitle: 'Haptic feedback on count',
            value: settings.vibrationEnabled,
            onChanged: ref.read(settingsProvider.notifier).setVibration,
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Appearance & Behaviour'),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.dark_mode,
            iconColor: Colors.indigoAccent,
            title: 'Dark Mode',
            subtitle: 'Use the dark spiritual theme',
            value: settings.darkMode,
            onChanged: ref.read(settingsProvider.notifier).setDarkMode,
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.restart_alt,
            iconColor: Colors.teal,
            title: 'Auto Reset',
            subtitle: 'Reset counter automatically at midnight',
            value: settings.autoReset,
            onChanged: ref.read(settingsProvider.notifier).setAutoReset,
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.screen_lock_portrait,
            iconColor: Colors.lightBlue,
            title: 'Keep Screen Awake',
            subtitle:
                'Stay unlocked while counting · releases after '
                '${AppConstants.wakelockIdleTimeout.inMinutes} min idle',
            value: settings.keepScreenAwake,
            onChanged: ref.read(settingsProvider.notifier).setKeepScreenAwake,
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Do Not Disturb'),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.do_not_disturb_on,
            iconColor: Colors.redAccent,
            title: 'Silence while chanting',
            subtitle: ref.read(dndServiceProvider).isSupported
                ? 'Mute calls & notifications while the app is open'
                : 'Not available on this device',
            value: settings.dndWhileCounting,
            onChanged: ref.read(dndServiceProvider).isSupported
                ? _onDndChanged
                : null,
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Reminders'),
          const SizedBox(height: 12),
          _ToggleCard(
            icon: Icons.notifications_active,
            iconColor: Colors.amber.shade700,
            title: 'Daily Reminder',
            subtitle: 'Remind me to start my namjap',
            value: settings.reminderEnabled,
            onChanged: _onReminderChanged,
          ),
          if (settings.reminderEnabled) ...[
            const SizedBox(height: 12),
            AppCard(
              onTap: _pickReminderTime,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Reminder time',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    TimeOfDay(
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute,
                    ).format(context),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Volume buttons are parked at a middle level for reliable '
                    'counting, so both up and down work consistently without '
                    'changing your media volume.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
