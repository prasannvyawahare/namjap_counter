import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/counter_controller.dart';
import 'providers/service_providers.dart';
import 'providers/settings_controller.dart';
import 'services/background_actions.dart';
import 'services/home_widget_service.dart';
import 'services/namjap_action.dart';
import 'services/notification_service.dart';
import 'storage/hive_service.dart';
import 'storage/namjap_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  final repository = NamjapRepository(
    recordsBox: HiveService.recordsBox,
    settingsBox: HiveService.settingsBox,
  );

  // Prepare notifications and re-arm the daily reminder so it survives timezone
  // changes and keeps firing across launches. Reused as the provider instance.
  final notificationService = NotificationService();
  await notificationService.init();
  final settings = repository.loadSettings();
  if (settings.reminderEnabled) {
    await notificationService.scheduleDaily(
      settings.reminderHour,
      settings.reminderMinute,
    );
  }

  final homeWidgetService = HomeWidgetService();
  await homeWidgetService.registerInteractivity(onHomeWidgetAction);

  // Built by hand rather than by ProviderScope so the notification and widget
  // buttons can reach the providers from outside the widget tree.
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      notificationServiceProvider.overrideWithValue(notificationService),
      homeWidgetServiceProvider.overrideWithValue(homeWidgetService),
    ],
  );

  // Claim ownership of counting before anything can arrive: from here on, a
  // notification or widget tap is handed to this isolate instead of being
  // applied against a second copy of the Hive boxes.
  NamjapActionBridge.host((action) {
    container.read(counterProvider.notifier).handleExternalAction(action);
  });

  // Reading it eagerly starts the controller, which posts the ongoing
  // notification and paints the widget for today.
  container.read(counterProvider);

  // A changed goal, or the notification being switched off, has to reach the
  // shade and the home screen straight away rather than at the next count.
  container.listen(settingsProvider, (previous, next) {
    if (previous == null) return;
    if (previous.dailyGoalCount != next.dailyGoalCount ||
        previous.darkMode != next.darkMode ||
        previous.progressNotificationEnabled !=
            next.progressNotificationEnabled ||
        previous.dismissNotificationOnGoalComplete !=
            next.dismissNotificationOnGoalComplete) {
      container.read(progressSyncProvider).push(settings: next);
    }
  });

  runApp(
    UncontrolledProviderScope(container: container, child: const NamjapApp()),
  );
}
