import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import 'models/daily_record.dart';
import 'models/user_settings.dart';

/// Handles Hive initialisation and exposes the opened boxes.
class HiveService {
  HiveService._();

  static late Box<DailyRecord> recordsBox;
  static late Box<UserSettings> settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(DailyRecordAdapter().typeId)) {
      Hive.registerAdapter(DailyRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(UserSettingsAdapter().typeId)) {
      Hive.registerAdapter(UserSettingsAdapter());
    }

    recordsBox = await Hive.openBox<DailyRecord>(AppConstants.recordsBoxName);
    settingsBox = await Hive.openBox<UserSettings>(
      AppConstants.settingsBoxName,
    );
  }
}
