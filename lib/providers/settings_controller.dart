import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/models/user_settings.dart';
import '../storage/namjap_repository.dart';
import 'service_providers.dart';

/// Owns the [UserSettings] and persists every change.
class SettingsController extends StateNotifier<UserSettings> {
  SettingsController(this._repo) : super(_repo.loadSettings());

  final NamjapRepository _repo;

  Future<void> _persist(UserSettings next) async {
    state = next;
    await _repo.saveSettings(next);
  }

  Future<void> completeOnboarding(String name) =>
      _persist(state.copyWith(name: name.trim(), onboarded: true));

  Future<void> updateName(String name) =>
      _persist(state.copyWith(name: name.trim()));

  Future<void> updateGoalCount(int count) =>
      _persist(state.copyWith(dailyGoalCount: count < 0 ? 0 : count));

  Future<void> setSound(bool value) =>
      _persist(state.copyWith(soundEnabled: value));

  Future<void> setVibration(bool value) =>
      _persist(state.copyWith(vibrationEnabled: value));

  Future<void> setDarkMode(bool value) =>
      _persist(state.copyWith(darkMode: value));

  Future<void> setAutoReset(bool value) =>
      _persist(state.copyWith(autoReset: value));

  Future<void> setActiveDate(String date) =>
      _persist(state.copyWith(activeDate: date));

  Future<void> setDndWhileCounting(bool value) =>
      _persist(state.copyWith(dndWhileCounting: value));

  Future<void> setReminderEnabled(bool value) =>
      _persist(state.copyWith(reminderEnabled: value));

  Future<void> setReminderTime(int hour, int minute) =>
      _persist(state.copyWith(reminderHour: hour, reminderMinute: minute));
}

final settingsProvider =
    StateNotifierProvider<SettingsController, UserSettings>((ref) {
  return SettingsController(ref.watch(repositoryProvider));
});

/// Theme mode derived from the dark-mode preference.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final dark = ref.watch(settingsProvider.select((s) => s.darkMode));
  return dark ? ThemeMode.dark : ThemeMode.light;
});
