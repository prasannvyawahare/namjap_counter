import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:namjap_counter/core/models/progress_snapshot.dart';
import 'package:namjap_counter/core/utils/date_helpers.dart';
import 'package:namjap_counter/services/namjap_action.dart';
import 'package:namjap_counter/services/progress_sync_service.dart';
import 'package:namjap_counter/storage/models/daily_record.dart';
import 'package:namjap_counter/storage/models/user_settings.dart';
import 'package:namjap_counter/storage/namjap_repository.dart';

void main() {
  group('ProgressSnapshot', () {
    ProgressSnapshot snapshot(int count, int goal) => ProgressSnapshot(
      dateKey: '2026-08-04',
      count: count,
      goalCount: goal,
      streak: 3,
      totalCount: count,
    );

    test('reports what is left of the goal', () {
      final s = snapshot(85, 108);
      expect(s.hasGoal, isTrue);
      expect(s.goalComplete, isFalse);
      expect(s.remaining, 23);
      expect(s.percent, 79);
    });

    test('completes on reaching the goal exactly', () {
      final s = snapshot(108, 108);
      expect(s.goalComplete, isTrue);
      expect(s.remaining, 0);
      expect(s.percent, 100);
    });

    test('overshooting stays complete without going negative or past 100%', () {
      final s = snapshot(150, 108);
      expect(s.goalComplete, isTrue);
      expect(s.remaining, 0);
      expect(s.percent, 100);
    });

    test('a zero goal is treated as no goal at all', () {
      final s = snapshot(40, 0);
      expect(s.hasGoal, isFalse);
      expect(s.goalComplete, isFalse);
      expect(s.remaining, 0);
      expect(s.progress, 0);
    });
  });

  group('NamjapAction routing', () {
    test('maps the notification button ids', () {
      expect(
        NamjapAction.fromNotificationId(NamjapAction.incrementNotificationId),
        NamjapAction.increment,
      );
      expect(
        NamjapAction.fromNotificationId(NamjapAction.decrementNotificationId),
        NamjapAction.decrement,
      );
    });

    test('a body tap carries no action id and counts nothing', () {
      expect(NamjapAction.fromNotificationId(null), isNull);
      expect(
        NamjapAction.fromNotificationId(NamjapAction.openNotificationId),
        isNull,
      );
    });

    test('maps the widget uris, falling back to a repaint', () {
      expect(
        NamjapAction.fromUri(Uri.parse('namjap://increment')),
        NamjapAction.increment,
      );
      expect(
        NamjapAction.fromUri(Uri.parse('namjap://decrement')),
        NamjapAction.decrement,
      );
      expect(
        NamjapAction.fromUri(Uri.parse('namjap://refresh')),
        NamjapAction.refresh,
      );
      expect(NamjapAction.fromUri(null), NamjapAction.refresh);
    });

    test('the uri a button broadcasts round-trips back to its action', () {
      for (final action in NamjapAction.values) {
        expect(NamjapAction.fromUri(action.uri), action);
      }
    });
  });

  group('ProgressSyncService.activeDate', () {
    test('auto-reset always lands on today, so a new day starts empty', () {
      final settings = UserSettings(autoReset: true, activeDate: '2020-01-01');
      expect(
        DateHelpers.key(ProgressSyncService.activeDate(settings)),
        DateHelpers.key(DateTime.now()),
      );
    });

    test('without auto-reset the pinned day is honoured', () {
      final settings = UserSettings(autoReset: false, activeDate: '2026-08-01');
      expect(
        DateHelpers.key(ProgressSyncService.activeDate(settings)),
        '2026-08-01',
      );
    });

    test('an unparseable pinned day falls back to today', () {
      final settings = UserSettings(autoReset: false, activeDate: 'nonsense');
      expect(
        DateHelpers.key(ProgressSyncService.activeDate(settings)),
        DateHelpers.key(DateTime.now()),
      );
    });
  });

  group('NamjapRepository', () {
    late Directory tempDir;
    late Box<DailyRecord> records;
    late Box<UserSettings> settings;
    late NamjapRepository repo;
    var boxSuffix = 0;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('namjap_progress_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(DailyRecordAdapter().typeId)) {
        Hive.registerAdapter(DailyRecordAdapter());
      }
      if (!Hive.isAdapterRegistered(UserSettingsAdapter().typeId)) {
        Hive.registerAdapter(UserSettingsAdapter());
      }
    });

    setUp(() async {
      boxSuffix++;
      records = await Hive.openBox<DailyRecord>('p_records_$boxSuffix');
      settings = await Hive.openBox<UserSettings>('p_settings_$boxSuffix');
      repo = NamjapRepository(recordsBox: records, settingsBox: settings);
    });

    tearDown(() async {
      await records.deleteFromDisk();
      await settings.deleteFromDisk();
    });

    tearDownAll(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    DateTime daysAgo(int n) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - n);
    }

    test('decrement can never take a day below zero', () async {
      final today = DateTime.now();
      await repo.setCount(today, 1);
      await repo.decrement(today);
      await repo.decrement(today);
      await repo.decrement(today);
      expect(repo.countFor(today), 0);
    });

    test('no records means no streak', () {
      expect(repo.currentStreak(), 0);
    });

    test('counts consecutive days back from today', () async {
      for (var i = 0; i < 4; i++) {
        await repo.setCount(daysAgo(i), 108);
      }
      expect(repo.currentStreak(), 4);
    });

    test('a gap ends the streak', () async {
      await repo.setCount(daysAgo(0), 10);
      await repo.setCount(daysAgo(1), 10);
      // Nothing on day 2.
      await repo.setCount(daysAgo(3), 10);
      expect(repo.currentStreak(), 2);
    });

    test('an empty today does not break a streak still in progress', () async {
      await repo.setCount(daysAgo(1), 108);
      await repo.setCount(daysAgo(2), 108);
      expect(repo.countFor(daysAgo(0)), 0);
      expect(repo.currentStreak(), 2);
    });

    test('a day that only ever held zero does not extend a streak', () async {
      await repo.setCount(daysAgo(1), 0);
      await repo.setCount(daysAgo(2), 108);
      expect(repo.currentStreak(), 0);
    });
  });
}
