import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/service_providers.dart';
import 'storage/hive_service.dart';
import 'storage/namjap_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  final repository = NamjapRepository(
    recordsBox: HiveService.recordsBox,
    settingsBox: HiveService.settingsBox,
  );

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
      ],
      child: const NamjapApp(),
    ),
  );
}
