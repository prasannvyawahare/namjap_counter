import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/date_helpers.dart';
import 'models/daily_record.dart';
import 'models/user_settings.dart';

/// Repository that owns all persistence. Everything is offline-first; each day
/// is a [DailyRecord] keyed by its date string, which makes the automatic
/// midnight reset free — a new day simply reads a new (empty) record.
class NamjapRepository {
  NamjapRepository({
    required Box<DailyRecord> recordsBox,
    required Box<UserSettings> settingsBox,
  }) : _records = recordsBox,
       _settings = settingsBox;

  final Box<DailyRecord> _records;
  final Box<UserSettings> _settings;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  UserSettings loadSettings() {
    final existing = _settings.get(AppConstants.userSettingsKey);
    if (existing != null) return existing;
    final fresh = UserSettings();
    _settings.put(AppConstants.userSettingsKey, fresh);
    return fresh;
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _settings.put(AppConstants.userSettingsKey, settings);
  }

  // ---------------------------------------------------------------------------
  // Daily records
  // ---------------------------------------------------------------------------

  DailyRecord recordFor(DateTime date) {
    final key = DateHelpers.key(date);
    final existing = _records.get(key);
    if (existing != null) return existing;
    return DailyRecord(date: key);
  }

  int countFor(DateTime date) => recordFor(date).count;

  Future<DailyRecord> setCount(DateTime date, int count) async {
    final key = DateHelpers.key(date);
    final safe = count < 0 ? 0 : count;
    final record = _records.get(key) ?? DailyRecord(date: key);
    record.count = safe;
    await _records.put(key, record);
    return record;
  }

  Future<DailyRecord> increment(DateTime date, {int by = 1}) async {
    return setCount(date, countFor(date) + by);
  }

  Future<DailyRecord> decrement(DateTime date, {int by = 1}) async {
    return setCount(date, countFor(date) - by);
  }

  /// All records that actually hold a count, newest first.
  List<DailyRecord> allRecords() {
    final list = _records.values.where((r) => r.count > 0).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Lifetime total across every recorded day.
  int totalCount() => _records.values.fold<int>(0, (sum, r) => sum + r.count);

  int countInRange(bool Function(DateTime date) test) {
    var total = 0;
    for (final record in _records.values) {
      final dt = record.dateTime;
      if (dt != null && test(dt)) total += record.count;
    }
    return total;
  }

  Future<void> clearAll() async {
    await _records.clear();
  }
}
