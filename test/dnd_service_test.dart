import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namjap_counter/services/dnd_service.dart';

/// Stands in for MainActivity's interruption-filter handling.
class _FakeSystemDnd {
  _FakeSystemDnd({this.hasPermission = true, this.silenced = false});

  bool hasPermission;
  bool silenced;
  int setCalls = 0;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'hasPermission':
        return hasPermission;
      case 'isEnabled':
        return silenced;
      case 'setEnabled':
        setCalls++;
        if (!hasPermission) return false;
        silenced = (call.arguments as Map)['enabled'] as bool;
        return true;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSystemDnd system;
  late DndService service;

  void install(_FakeSystemDnd fake) {
    system = fake;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('namjap/dnd'),
          fake.handle,
        );
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    install(_FakeSystemDnd());
    service = DndService();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('namjap/dnd'), null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('a single holder silences and un-silences the phone', () async {
    final dashboard = Object();

    await service.acquire(dashboard);
    expect(system.silenced, isTrue);

    await service.release(dashboard);
    expect(system.silenced, isFalse);
  });

  test('silence lasts until the last holder lets go', () async {
    final dashboard = Object();
    final focus = Object();

    await service.acquire(dashboard);
    await service.acquire(focus);
    expect(system.silenced, isTrue);

    await service.release(focus);
    expect(system.silenced, isTrue, reason: 'the dashboard still wants it');

    await service.release(dashboard);
    expect(system.silenced, isFalse);
  });

  test(
    'leaving Focus releases the phone when the dashboard never wanted it',
    () async {
      final focus = Object();

      // The reported bug: the preference is off, so the dashboard holds
      // nothing, and Focus is the only reason the phone went quiet.
      await service.acquire(focus);
      expect(system.silenced, isTrue);

      await service.release(focus);
      expect(system.silenced, isFalse);
      expect(service.isHeld, isFalse);
    },
  );

  test('a Do Not Disturb the user set themselves is left alone', () async {
    install(_FakeSystemDnd(silenced: true));
    service = DndService();
    final focus = Object();

    await service.acquire(focus);
    expect(system.silenced, isTrue);
    expect(
      system.setCalls,
      0,
      reason: 'already quiet, so there was nothing to change',
    );

    await service.release(focus);
    expect(
      system.silenced,
      isTrue,
      reason: 'we did not silence it, so we must not un-silence it',
    );
  });

  test('repeat acquires from one owner are a single hold', () async {
    final dashboard = Object();

    await service.acquire(dashboard);
    await service.acquire(dashboard);
    await service.release(dashboard);

    expect(system.silenced, isFalse);
  });

  test('releasing a non-holder changes nothing', () async {
    final dashboard = Object();

    await service.acquire(dashboard);
    await service.release(Object());

    expect(system.silenced, isTrue);
    expect(service.isHeld, isTrue);
  });

  test('overlapping unawaited calls settle on the final intent', () async {
    final dashboard = Object();
    final focus = Object();

    // How these actually arrive: fired from build callbacks and dispose,
    // nobody awaiting them.
    service.acquire(dashboard);
    service.acquire(focus);
    service.release(focus);
    service.release(dashboard);
    await service.settled;

    expect(system.silenced, isFalse);
    expect(service.isHeld, isFalse);
  });

  test('without permission nothing is claimed', () async {
    install(_FakeSystemDnd(hasPermission: false));
    service = DndService();
    final focus = Object();

    await service.acquire(focus);
    expect(system.silenced, isFalse);
    expect(service.isHeld, isFalse);
  });
}
