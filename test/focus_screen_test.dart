import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Swallows the volume-key stream. Focus mode claims the hardware buttons the
/// moment it opens, and without a handler here `EventChannel` reports the
/// missing plugin straight to `FlutterError`, which fails the test before it
/// has done anything.
class _SilentVolumeKeys extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<DailyRecord> records;
  late Box<UserSettings> settings;
  var boxSuffix = 0;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockStreamHandler(
      const EventChannel('namjap/volume_buttons'),
      _SilentVolumeKeys(),
    );
    // Focus mode also asks for Do Not Disturb; answering keeps the log clean.
    messenger.setMockMethodCallHandler(const MethodChannel('namjap/dnd'), (
      call,
    ) async {
      return switch (call.method) {
        'hasPermission' || 'isEnabled' || 'setEnabled' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockStreamHandler(
      const EventChannel('namjap/volume_buttons'),
      null,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('namjap/dnd'), null);
  });

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

  // The boxes are deliberately left alone between tests. Deleting them here
  // deadlocks: `deleteFromDisk` waits on Hive's write lock, which is held by a
  // continuation queued on the widget test's fake-async zone, and that zone
  // only advances on a `pump` this callback has no way to issue. Fresh box
  // names per test already give the isolation the deletion was there for.
  tearDownAll(() async {
    // Best effort. Windows keeps handles on the open boxes, so a failure here
    // means a stray temp directory, not a broken test run.
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
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
  ///
  /// Two pumps, not one. The write's continuation runs on the first, which is
  /// what finally moves the counter state; the rebuild that state schedules
  /// only gets drawn on the next frame. With a single pump the screen still
  /// shows the previous number even though the provider has already moved on.
  Future<void> settleWrites(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
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
