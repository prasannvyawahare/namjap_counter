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
  static const String keyDark = 'namjap_dark';

  /// Whether the widget's +1 button has a Dart callback to call into.
  ///
  /// `home_widget` remembers the callback as a raw Dart handle in shared
  /// preferences, and those handles do not survive a rebuild of the app — the
  /// stored one goes on pointing at nothing until [registerInteractivity] runs
  /// again, which only happens when the app is next opened. A tap in that
  /// window reaches a background worker that cannot find its entry point and
  /// gives up without a trace. The widget reads this flag to know whether to
  /// trust the handle, and falls back to opening the app when it can't.
  static const String keyCallbackReady = 'namjap_callback_ready';

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
      // Only now is the stored handle known to point at this build's code.
      await HomeWidget.saveWidgetData<bool>(keyCallbackReady, true);
      await HomeWidget.updateWidget(androidName: androidWidgetName);
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
        HomeWidget.saveWidgetData<bool>(keyDark, snapshot.darkMode),
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
