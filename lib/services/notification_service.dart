import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the single daily "start your namjap" reminder as a local
/// notification that repeats every day at the chosen time.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Fixed id — there is only ever one daily reminder, so re-scheduling simply
  /// overwrites it.
  static const int _reminderId = 1001;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'namjap_reminder',
      'Namjap Reminders',
      channelDescription: 'Daily reminder to begin your chanting.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized) return;
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
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Requests OS permission to post notifications. Returns whether it is
  /// (now) granted. Safe to call repeatedly.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
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

  /// (Re)schedules the daily reminder at [hour]:[minute]. Uses inexact
  /// scheduling so it works without the exact-alarm permission on Android 12+.
  Future<void> scheduleDaily(int hour, int minute) async {
    await init();
    await _plugin.cancel(_reminderId);
    await _plugin.zonedSchedule(
      _reminderId,
      'Time for your Namjap 🙏',
      'Take a mindful moment and begin your chanting.',
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder() async {
    await init();
    await _plugin.cancel(_reminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
