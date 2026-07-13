import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/service_providers.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const NamjapApp(),
    ),
  );
}
