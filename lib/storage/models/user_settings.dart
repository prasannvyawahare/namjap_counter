import 'package:hive/hive.dart';

import '../../core/constants/app_constants.dart';

part 'user_settings.g.dart';

/// User profile, preferences and daily goal. A single instance is stored in the
/// settings box under [AppConstants.userSettingsKey].
@HiveType(typeId: 1)
class UserSettings extends HiveObject {
  UserSettings({
    this.name = '',
    this.dailyGoalCount = AppConstants.defaultDailyGoalCount,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.darkMode = true,
    this.autoReset = true,
    this.onboarded = false,
    this.activeDate,
    this.dndWhileCounting = false,
    this.reminderEnabled = false,
    this.reminderHour = 6,
    this.reminderMinute = 0,
    this.keepScreenAwake = true,
  });

  @HiveField(0)
  String name;

  /// Daily target in counts. The Mala goal is derived from this.
  @HiveField(1)
  int dailyGoalCount;

  @HiveField(2)
  bool soundEnabled;

  @HiveField(3)
  bool vibrationEnabled;

  @HiveField(4)
  bool darkMode;

  @HiveField(5)
  bool autoReset;

  @HiveField(6)
  bool onboarded;

  /// The date (`yyyy-MM-dd`) the counter is currently pointed at. Used to detect
  /// midnight rollovers for the automatic reset behaviour.
  @HiveField(7)
  String? activeDate;

  /// When true, the app turns on the system Do Not Disturb (Android only) while
  /// it is in the foreground so calls and notifications don't break the chant.
  @HiveField(8)
  bool dndWhileCounting;

  /// Whether the daily "start your namjap" reminder notification is scheduled.
  @HiveField(9)
  bool reminderEnabled;

  /// Time of day (24h) for the daily reminder.
  @HiveField(10)
  int reminderHour;

  @HiveField(11)
  int reminderMinute;

  /// Whether the screen is held awake while the dashboard is in the foreground,
  /// so a long volume-button session isn't cut short by the idle lock. The
  /// wakelock is still released after a stretch with no counting, so leaving the
  /// dashboard open by accident doesn't drain the battery.
  ///
  /// `defaultValue` matters here: settings persisted before this field existed
  /// have no value at index 12, and without it the adapter would cast a null
  /// straight to `bool` and crash on load for every existing user.
  @HiveField(12, defaultValue: true)
  bool keepScreenAwake;

  int get dailyGoalMala => dailyGoalCount ~/ AppConstants.countsPerMala;

  UserSettings copyWith({
    String? name,
    int? dailyGoalCount,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? darkMode,
    bool? autoReset,
    bool? onboarded,
    String? activeDate,
    bool? dndWhileCounting,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? keepScreenAwake,
  }) {
    return UserSettings(
      name: name ?? this.name,
      dailyGoalCount: dailyGoalCount ?? this.dailyGoalCount,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      darkMode: darkMode ?? this.darkMode,
      autoReset: autoReset ?? this.autoReset,
      onboarded: onboarded ?? this.onboarded,
      activeDate: activeDate ?? this.activeDate,
      dndWhileCounting: dndWhileCounting ?? this.dndWhileCounting,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    );
  }
}
