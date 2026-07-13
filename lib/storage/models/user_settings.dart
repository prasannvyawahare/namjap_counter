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
    );
  }
}
