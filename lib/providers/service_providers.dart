import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dnd_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/volume_button_service.dart';
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

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
