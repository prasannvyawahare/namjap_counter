import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/counter/dashboard_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'providers/settings_controller.dart';

class NamjapApp extends ConsumerWidget {
  const NamjapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));

    return MaterialApp(
      title: 'Namjap Counter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: onboarded ? const DashboardScreen() : const WelcomeScreen(),
    );
  }
}
