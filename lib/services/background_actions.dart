import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../storage/hive_service.dart';
import '../storage/namjap_repository.dart';
import 'home_widget_service.dart';
import 'namjap_action.dart';
import 'notification_service.dart';
import 'progress_sync_service.dart';

/// Entry points the OS calls when the app itself may not be running.
///
/// Both the notification quick actions and the widget buttons land here, in a
/// short-lived isolate spun up by their plugin. Nothing in this file owns any
/// counting rules: it either hands the action to the live app or, when there
/// isn't one, opens storage and runs it through the very same
/// [ProgressSyncService] the app uses.

/// Called by `flutter_local_notifications` for the +1 / -1 buttons.
@pragma('vm:entry-point')
void onNotificationResponse(NotificationResponse response) {
  final action = NamjapAction.fromNotificationId(response.actionId);
  // A tap on the body (no action id) just opens the app; nothing to apply.
  if (action == null) return;
  handleBackgroundAction(action);
}

/// Called by `home_widget` for the widget's +1 button and for the midnight
/// rollover broadcast.
@pragma('vm:entry-point')
Future<void> onHomeWidgetAction(Uri? uri) =>
    handleBackgroundAction(NamjapAction.fromUri(uri));

/// Applies [action] wherever it can be applied safely.
///
/// The running app is always given first refusal. That isn't an optimisation —
/// it's what stops two isolates holding the same Hive boxes open, and it's also
/// what makes the dashboard update live when someone presses +1 in the shade.
Future<void> handleBackgroundAction(NamjapAction action) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (NamjapActionBridge.offer(action)) return;

  try {
    await HiveService.init();
    final repository = NamjapRepository(
      recordsBox: HiveService.recordsBox,
      settingsBox: HiveService.settingsBox,
    );
    final sync = ProgressSyncService(
      repository: repository,
      notificationService: NotificationService(),
      homeWidgetService: HomeWidgetService(),
    );
    await sync.apply(action);
  } catch (e, stack) {
    debugPrint('handleBackgroundAction($action) failed: $e\n$stack');
  } finally {
    // Release the box files so the app can open them cleanly on next launch.
    await HiveService.close();
  }
}
