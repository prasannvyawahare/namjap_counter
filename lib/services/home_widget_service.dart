import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/models/progress_snapshot.dart';
import 'namjap_action.dart';

/// Pushes the current progress to the Android home screen widget.
///
/// The widget is a plain `RemoteViews` layout on the native side; all it ever
/// reads is the handful of keys written here, so this is the only place that
/// decides what it can display.
class HomeWidgetService {
  HomeWidgetService();

  /// Must match the provider class registered in AndroidManifest.xml.
  static const String androidWidgetName = 'NamjapWidgetProvider';

  static const String keyDate = 'namjap_date';
  static const String keyCount = 'namjap_count';
  static const String keyGoal = 'namjap_goal';
  static const String keyRemaining = 'namjap_remaining';
  static const String keyStreak = 'namjap_streak';
  static const String keyPercent = 'namjap_percent';

  /// Widgets only exist on Android here; everywhere else this is a no-op so
  /// callers don't have to guard.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Registers the Dart entry point the widget's buttons call into. Only
  /// needed once per app launch.
  Future<void> registerInteractivity(
    Future<void> Function(Uri?) callback,
  ) async {
    if (!isSupported) return;
    try {
      await HomeWidget.registerInteractivityCallback(callback);
    } catch (e) {
      debugPrint('HomeWidgetService: could not register callback: $e');
    }
  }

  /// Writes [snapshot] to shared storage and asks the launcher to redraw.
  Future<void> push(ProgressSnapshot snapshot) async {
    if (!isSupported) return;
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyDate, snapshot.dateKey),
        HomeWidget.saveWidgetData<int>(keyCount, snapshot.count),
        HomeWidget.saveWidgetData<int>(keyGoal, snapshot.goalCount),
        HomeWidget.saveWidgetData<int>(keyRemaining, snapshot.remaining),
        HomeWidget.saveWidgetData<int>(keyStreak, snapshot.streak),
        HomeWidget.saveWidgetData<int>(keyPercent, snapshot.percent),
      ]);
      await HomeWidget.updateWidget(androidName: androidWidgetName);
    } catch (e) {
      // A missing widget is the normal case — the user may never have added
      // one. Never let it break the count that triggered this.
      debugPrint('HomeWidgetService: update skipped: $e');
    }
  }

  /// The uri the native `+1` button broadcasts, exposed so the Kotlin side and
  /// Dart side can't drift apart.
  static Uri get incrementUri => NamjapAction.increment.uri;
}
