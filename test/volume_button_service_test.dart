import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namjap_counter/services/volume_button_service.dart';

/// Drives the `namjap/volume_buttons` EventChannel the way MainActivity does,
/// so a test can press a volume key.
class _FakeVolumeKeys extends MockStreamHandler {
  MockStreamHandlerEventSink? _sink;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _sink = events;
  }

  @override
  void onCancel(Object? arguments) {
    _sink = null;
  }

  bool get isListening => _sink != null;

  /// Presses a volume key and lets the event travel the channel: delivery
  /// through the binary messenger is asynchronous, so callers must await this
  /// before asserting on what the handlers saw.
  Future<void> press(String direction) async {
    _sink?.success(direction);
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeVolumeKeys keys;
  late VolumeButtonService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    keys = _FakeVolumeKeys();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('namjap/volume_buttons'),
          keys,
        );
    service = VolumeButtonService();
  });

  tearDown(() async {
    await service.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('namjap/volume_buttons'),
          null,
        );
    debugDefaultTargetPlatformOverride = null;
  });

  /// Stands in for a screen that can own the keys.
  ({Object owner, List<String> log, Future<void> Function() claim}) screen(
    String name,
  ) {
    final owner = Object();
    final log = <String>[];
    return (
      owner: owner,
      log: log,
      claim: () => service.start(
        owner: owner,
        onUp: () => log.add('$name:up'),
        onDown: () => log.add('$name:down'),
      ),
    );
  }

  test('the claiming screen receives the presses', () async {
    final dashboard = screen('dashboard');
    await dashboard.claim();
    await pumpEventQueue();

    await keys.press('up');
    await keys.press('down');

    expect(dashboard.log, ['dashboard:up', 'dashboard:down']);
    expect(service.isOwnedBy(dashboard.owner), isTrue);
  });

  test('a second screen takes over without dropping the stream', () async {
    final dashboard = screen('dashboard');
    final focus = screen('focus');
    await dashboard.claim();
    await pumpEventQueue();
    await focus.claim();
    await pumpEventQueue();

    await keys.press('up');

    expect(focus.log, ['focus:up']);
    expect(dashboard.log, isEmpty);
    // The native side must still be intercepting, or the keys would fall
    // through to the system volume slider mid-session.
    expect(keys.isListening, isTrue);
  });

  test('a departing screen cannot release keys it no longer owns', () async {
    final dashboard = screen('dashboard');
    final focus = screen('focus');
    await dashboard.claim();
    await pumpEventQueue();
    await focus.claim();
    await pumpEventQueue();

    // Focus tears down, but the dashboard has already re-claimed on the way
    // back. This is the ordering that used to leave the buttons dead.
    await dashboard.claim();
    await pumpEventQueue();
    await service.stop(owner: focus.owner);

    await keys.press('up');

    expect(dashboard.log, ['dashboard:up']);
    expect(service.isOwnedBy(dashboard.owner), isTrue);
    expect(service.isActive, isTrue);
  });

  test('the owner releasing really does release', () async {
    final focus = screen('focus');
    await focus.claim();
    await pumpEventQueue();
    await service.stop(owner: focus.owner);

    await keys.press('up');

    expect(focus.log, isEmpty);
    expect(service.isActive, isFalse);
    expect(keys.isListening, isFalse);
  });

  test('re-claiming after a release starts a fresh stream', () async {
    final dashboard = screen('dashboard');
    await dashboard.claim();
    await pumpEventQueue();
    await service.stop(owner: dashboard.owner);
    expect(keys.isListening, isFalse);

    // What the dashboard now does when a pushed route closes.
    await dashboard.claim();
    await pumpEventQueue();

    await keys.press('down');

    expect(keys.isListening, isTrue);
    expect(dashboard.log, ['dashboard:down']);
  });
}
