import '../core/models/progress_snapshot.dart';
import '../core/utils/date_helpers.dart';
import '../storage/models/user_settings.dart';
import '../storage/namjap_repository.dart';
import 'home_widget_service.dart';
import 'namjap_action.dart';
import 'notification_service.dart';

/// Keeps the notification and the home screen widget showing exactly what Hive
/// holds.
///
/// Every count — from the dashboard, a notification button or a widget button —
/// ends here, so the two out-of-app surfaces are written from one place and
/// from one read of storage. Counting itself is still
/// [NamjapRepository]'s job; this only decides *when* to repaint and *what*
/// today's numbers are.
class ProgressSyncService {
  ProgressSyncService({
    required NamjapRepository repository,
    required NotificationService notificationService,
    required HomeWidgetService homeWidgetService,
  }) : _repo = repository,
       _notifications = notificationService,
       _widget = homeWidgetService;

  final NamjapRepository _repo;
  final NotificationService _notifications;
  final HomeWidgetService _widget;

  /// Applies a count coming from outside the UI, then repaints.
  ///
  /// Deliberately routed through [NamjapRepository.increment] /
  /// [NamjapRepository.decrement] — the same methods the dashboard uses — so
  /// the clamp at zero and the per-day record layout stay in one place.
  Future<ProgressSnapshot> apply(NamjapAction action) async {
    final settings = _repo.loadSettings();
    final date = activeDate(settings);
    switch (action) {
      case NamjapAction.increment:
        await _repo.increment(date);
      case NamjapAction.decrement:
        await _repo.decrement(date);
      case NamjapAction.refresh:
        break;
    }
    return push(settings: settings);
  }

  /// Re-reads storage and repaints both surfaces.
  ///
  /// [settings] may be passed by the running app so an in-flight preference
  /// change is honoured before it has finished persisting; otherwise the
  /// stored copy is used.
  Future<ProgressSnapshot> push({UserSettings? settings}) async {
    final resolved = settings ?? _repo.loadSettings();
    final snapshot = read(settings: resolved);

    if (resolved.progressNotificationEnabled) {
      await _notifications.showProgress(
        snapshot,
        dismissWhenComplete: resolved.dismissNotificationOnGoalComplete,
      );
    } else {
      await _notifications.cancelProgress();
    }
    await _widget.push(snapshot);
    return snapshot;
  }

  /// Builds the snapshot for the currently active day without touching either
  /// surface.
  ProgressSnapshot read({UserSettings? settings}) {
    final resolved = settings ?? _repo.loadSettings();
    final date = activeDate(resolved);
    return ProgressSnapshot(
      dateKey: DateHelpers.key(date),
      count: _repo.countFor(date),
      goalCount: resolved.dailyGoalCount,
      streak: _repo.currentStreak(asOf: date),
      totalCount: _repo.totalCount(),
      darkMode: resolved.darkMode,
    );
  }

  /// The day a count belongs to.
  ///
  /// Mirrors [CounterController]'s rule: with auto-reset on it is always today,
  /// so a tap at 00:01 lands on the new day and the notification resets itself.
  /// With auto-reset off the user's pinned day is honoured instead.
  static DateTime activeDate(UserSettings settings) {
    final now = DateTime.now();
    if (settings.autoReset) return now;
    final pinned = settings.activeDate;
    if (pinned == null) return now;
    return DateHelpers.parseKey(pinned) ?? now;
  }
}
