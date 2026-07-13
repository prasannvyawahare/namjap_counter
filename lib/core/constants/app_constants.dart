/// Global, compile-time constants for the Namjap Counter app.
class AppConstants {
  AppConstants._();

  /// The single most important rule of the app: 108 counts == 1 Mala.
  static const int countsPerMala = 108;

  /// Default daily target expressed in counts (1 Mala).
  static const int defaultDailyGoalCount = 108;

  // Hive box names.
  static const String settingsBoxName = 'settings_box';
  static const String recordsBoxName = 'records_box';

  // Hive keys inside the settings box.
  static const String userSettingsKey = 'user_settings';

  // Motivational spiritual quotes shown on the dashboard.
  static const List<String> quotes = [
    'The mind is everything. What you think you become.',
    'Chant the name, and the name will carry you.',
    'A single moment of presence is worth a thousand mantras rushed.',
    'Devotion is not in the count, but in the heart behind it.',
    'Still the mind, and the divine reveals itself.',
    'Every repetition is a step closer to the Self.',
    'Where there is faith, there is light.',
    'Hari Om — let the sound dissolve the noise within.',
  ];
}
