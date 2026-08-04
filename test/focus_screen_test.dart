import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:namjap_counter/core/constants/app_constants.dart';
import 'package:namjap_counter/features/focus/focus_screen.dart';
import 'package:namjap_counter/providers/counter_controller.dart';
import 'package:namjap_counter/providers/service_providers.dart';
import 'package:namjap_counter/storage/models/daily_record.dart';
import 'package:namjap_counter/storage/models/user_settings.dart';
import 'package:namjap_counter/storage/namjap_repository.dart';

void main() {
  late Directory tempDir;
  late Box<DailyRecord> records;
  late Box<UserSettings> settings;
  var boxSuffix = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('namjap_focus_test');
    Hive
      ..init(tempDir.path)
      ..registerAdapter(DailyRecordAdapter())
      ..registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    // A fresh pair of boxes per test so counts don't leak between them.
    boxSuffix++;
    records = await Hive.openBox<DailyRecord>('records_$boxSuffix');
    settings = await Hive.openBox<UserSettings>('settings_$boxSuffix');
  });

  tearDown(() async {
    await records.deleteFromDisk();
    await settings.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) {
    final repo = NamjapRepository(recordsBox: records, settingsBox: settings);
    return ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(FocusScreen)));

  /// A count is only visible once the Hive write behind it completes, and that
  /// is real I/O — [WidgetTester.pump] alone will never let it finish.
  Future<void> settleWrites(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  /// Taps the counting surface, away from the close button and target chip.
  Future<void> tapSurface(WidgetTester tester, {int times = 1}) async {
    final centre = tester.getCenter(find.byType(Scaffold));
    for (var i = 0; i < times; i++) {
      await tester.tapAt(centre);
      await settleWrites(tester);
    }
  }

  /// Bulk counts pushed through the provider rather than 108 real gestures —
  /// the screen reacts to the count, not to how it was produced.
  Future<void> countTo(WidgetTester tester, int times) async {
    final notifier = containerOf(tester).read(counterProvider.notifier);
    await tester.runAsync(() async {
      for (var i = 0; i < times; i++) {
        await notifier.increment();
      }
    });
    await tester.pump();
  }

  /// Lets the count pulse and the hint timer expire so no timers are pending.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping anywhere counts', (tester) async {
    await tester.pumpWidget(wrap(const FocusScreen()));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);

    await tapSurface(tester, times: 3);
    expect(find.text('3'), findsOneWidget);

    await quiesce(tester);
  });

  testWidgets('long press undoes a count', (tester) async {
    await tester.pumpWidget(wrap(const FocusScreen()));
    await tester.pump();

    await tapSurface(tester, times: 2);
    expect(find.text('2'), findsOneWidget);

    await tester.longPressAt(tester.getCenter(find.byType(Scaffold)));
    await settleWrites(tester);
    expect(find.text('1'), findsOneWidget);

    await quiesce(tester);
  });

  testWidgets('session target pauses counting once it is met', (tester) async {
    await tester.pumpWidget(wrap(const FocusScreen(targetMala: 1)));
    await tester.pump();

    await countTo(tester, AppConstants.countsPerMala - 1);
    expect(find.text('1 Mala complete'), findsNothing);

    await tapSurface(tester);
    expect(find.text('1 Mala complete'), findsOneWidget);

    // Further taps land on the overlay and must not keep counting.
    await tapSurface(tester, times: 5);
    expect(
      containerOf(tester).read(counterProvider).todayCount,
      AppConstants.countsPerMala,
    );

    await quiesce(tester);
  });

  testWidgets('an open-ended session never interrupts', (tester) async {
    await tester.pumpWidget(wrap(const FocusScreen()));
    await tester.pump();

    await countTo(tester, AppConstants.countsPerMala + 2);
    expect(find.textContaining('complete'), findsNothing);
    expect(find.text('110'), findsOneWidget);

    await quiesce(tester);
  });
}
