import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dnd_service.dart';
import '../services/haptic_service.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/progress_sync_service.dart';
import '../services/share_service.dart';
import '../services/volume_button_service.dart';
import '../services/wakelock_service.dart';
import '../storage/namjap_repository.dart';

/// Overridden in `main()` once Hive is initialised.
final repositoryProvider = Provider<NamjapRepository>((ref) {
  throw UnimplementedError('repositoryProvider must be overridden in main()');
});

final hapticServiceProvider = Provider<HapticService>((ref) => HapticService());

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

final volumeButtonServiceProvider = Provider<VolumeButtonService>((ref) {
  final service = VolumeButtonService();
  ref.onDispose(service.dispose);
  return service;
});

final dndServiceProvider = Provider<DndService>((ref) => DndService());

final wakelockServiceProvider = Provider<WakelockService>((ref) {
  final service = WakelockService();
  ref.onDispose(service.dispose);
  return service;
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => HomeWidgetService(),
);

/// Keeps the ongoing notification and the home screen widget in step with
/// storage. Everything that changes a count pushes through here.
final progressSyncProvider = Provider<ProgressSyncService>((ref) {
  return ProgressSyncService(
    repository: ref.watch(repositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    homeWidgetService: ref.watch(homeWidgetServiceProvider),
  );
});
