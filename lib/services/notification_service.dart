import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/models/progress_snapshot.dart';
import 'background_actions.dart';
import 'namjap_action.dart';

/// Owns every notification the app posts:
///
/// * the once-a-day "start your namjap" reminder, scheduled ahead of time, and
/// * the ongoing progress notification, which mirrors today's count and carries
///   the +1 / -1 quick actions.
///
/// Both live here because they share one plugin instance, one initialisation
/// and one permission grant.
class NotificationService {
  NotificationService();

  /// Built on first use, not on construction: every entry point guards on
  /// [isSupported] first, so on a platform with no notification shade the
  /// plugin is never reached for at all.
  late final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Set once the plugin has been found to be unreachable — a test host, or a
  /// platform with no notification support compiled in. Remembered so the
  /// progress notification, which is rebuilt on every single count, doesn't pay
  /// for a doomed initialisation each time.
  bool _unavailable = false;

  /// Fixed ids — there is only ever one of each, so re-posting simply
  /// overwrites, which is what keeps duplicates impossible.
  static const int _reminderId = 1001;
  static const int progressId = 1002;

  static const String _progressChannelId = 'namjap_progress';

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'namjap_reminder',
      'Namjap Reminders',
      channelDescription: 'Daily reminder to begin your chanting.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Prepares the plugin. Returns whether notifications can actually be posted.
  Future<bool> init() async {
    if (_initialized) return true;
    if (_unavailable) return false;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      debugPrint('NotificationService: could not resolve local timezone: $e');
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(
        settings,
        // Quick-action buttons don't open the UI, so the OS hands them to a
        // background isolate. Both callbacks route into the same handler.
        onDidReceiveNotificationResponse: onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: onNotificationResponse,
      );
      _initialized = true;
    } catch (e) {
      // No plugin to talk to. Counting must carry on regardless — the shade is
      // a convenience, and an unusable one is not worth an error per bead.
      _unavailable = true;
      debugPrint('NotificationService: notifications unavailable: $e');
    }
    return _initialized;
  }

  /// Requests OS permission to post notifications. Returns whether it is
  /// (now) granted. Safe to call repeatedly.
  Future<bool> requestPermission() async {
    if (!await init()) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Daily reminder
  // ---------------------------------------------------------------------------

  /// (Re)schedules the daily reminder at [hour]:[minute]. Uses inexact
  /// scheduling so it works without the exact-alarm permission on Android 12+.
  Future<void> scheduleDaily(int hour, int minute) async {
    if (!await init()) return;
    await _plugin.cancel(_reminderId);
    await _plugin.zonedSchedule(
      _reminderId,
      'Time for your Namjap 🙏',
      'Take a mindful moment and begin your chanting.',
      _nextInstanceOf(hour, minute),
      _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder() async {
    if (!await init()) return;
    await _plugin.cancel(_reminderId);
  }

  // ---------------------------------------------------------------------------
  // Ongoing progress notification
  // ---------------------------------------------------------------------------

  /// Whether this platform has a notification shade we post progress to.
  ///
  /// Guarded because the progress notification is driven from
  /// [CounterController] on *every* count. Without this, a plain widget test —
  /// or a desktop host — would drag the timezone database and the notification
  /// plugin into a code path that has nothing to do with counting.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Posts (or updates in place) the progress notification for [snapshot].
  ///
  /// Re-using [progressId] means every call replaces the previous one, so a
  /// hundred increments still leave exactly one notification in the shade.
  Future<void> showProgress(
    ProgressSnapshot snapshot, {
    required bool dismissWhenComplete,
  }) async {
    if (!isSupported || !await init()) return;

    if (snapshot.goalComplete && dismissWhenComplete) {
      await cancelProgress();
      return;
    }

    final complete = snapshot.goalComplete;
    final title = complete ? '🎉 Daily Goal Completed' : 'Namjap Counter';
    final body = _body(snapshot);

    final android = AndroidNotificationDetails(
      _progressChannelId,
      'Chanting Progress',
      channelDescription:
          "Live view of today's count, with quick +1 and -1 actions.",
      // Low importance keeps it silent and out of the way: it is a dashboard,
      // not an alert, and it is rewritten on every single count.
      importance: Importance.low,
      priority: Priority.low,
      ongoing: !complete,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      // The status bar icon has to stay a flat white silhouette — Android
      // tints it — so the app's own icon goes in the large slot beside the
      // text, which is the only place a full-colour mark belongs.
      icon: 'ic_stat_namjap',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFFFF9800),
      colorized: false,
      // Android drops the notification by itself the moment the day ends. It
      // costs nothing, needs no alarm and no running process, and means a
      // phone left untouched overnight never wakes up showing yesterday.
      timeoutAfter: _millisUntilMidnight(),
      showProgress: snapshot.hasGoal,
      maxProgress: snapshot.hasGoal ? snapshot.goalCount : 0,
      progress: snapshot.hasGoal
          ? snapshot.count.clamp(0, snapshot.goalCount)
          : 0,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: complete ? null : _summary(snapshot),
      ),
      actions: complete ? const [] : _actions,
    );

    await _plugin.show(
      progressId,
      title,
      body,
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> cancelProgress() async {
    if (!isSupported || !await init()) return;
    await _plugin.cancel(progressId);
  }

  /// The quick actions, laid out left to right in this order.
  ///
  /// +1 is last so it lands on the right, under the thumb and matching the
  /// home screen widget: it is the one pressed over and over, while Open is
  /// the rare escape hatch.
  ///
  /// `cancelNotification: false` is essential — the plugin's broadcast receiver
  /// dismisses the notification on a tap otherwise, so the ongoing notification
  /// would vanish the first time someone pressed +1.
  static const List<AndroidNotificationAction> _actions = [
    AndroidNotificationAction(
      NamjapAction.openNotificationId,
      '🏠 Open App',
      cancelNotification: false,
      // The one action that does launch the UI, so it goes to the activity
      // rather than the background isolate.
      showsUserInterface: true,
    ),
    AndroidNotificationAction(
      NamjapAction.decrementNotificationId,
      '➖ -1 Chant',
      cancelNotification: false,
      showsUserInterface: false,
    ),
    AndroidNotificationAction(
      NamjapAction.incrementNotificationId,
      '➕ +1 Chant',
      cancelNotification: false,
      showsUserInterface: false,
    ),
  ];

  static String _body(ProgressSnapshot s) {
    if (s.goalComplete) {
      return '${s.count} / ${s.goalCount} Chants\n\nHari Om 🙏';
    }
    if (!s.hasGoal) {
      return "Today's Progress\n\n${s.count} Chants\n"
          '${s.breakdown.formatted}';
    }
    return "Today's Progress\n\n${s.count} / ${s.goalCount} Chants\n"
        'Remaining: ${s.remaining}';
  }

  static int _millisUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    // Floored at a second so a post landing exactly on the boundary isn't
    // handed a zero, which Android reads as "no timeout".
    return midnight.difference(now).inMilliseconds.clamp(1000, 86400000);
  }

  static String? _summary(ProgressSnapshot s) =>
      s.hasGoal ? '${s.percent}% · ${s.breakdown.formatted}' : null;

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
