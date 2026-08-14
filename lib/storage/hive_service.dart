import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import 'models/daily_record.dart';
import 'models/user_settings.dart';

/// Handles Hive initialisation and exposes the opened boxes.
class HiveService {
  HiveService._();

  static late Box<DailyRecord> recordsBox;
  static late Box<UserSettings> settingsBox;

  static bool _open = false;

  /// Whether the boxes are currently open in *this* isolate.
  static bool get isOpen => _open;

  static Future<void> init() async {
    if (_open) return;
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
    _open = true;
  }

  /// Closes the boxes and flushes them to disk.
  ///
  /// The app never calls this — it holds the boxes for its whole life. It
  /// exists for the short-lived background isolate that services notification
  /// and widget buttons while the app is dead: that isolate must hand the files
  /// back before it exits, or the next launch inherits a lock.
  static Future<void> close() async {
    if (!_open) return;
    _open = false;
    await Hive.close();
  }
}
