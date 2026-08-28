import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlock_detector/unlock_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnlockDetectorStatus', () {
    test('fromString maps every platform value', () {
      expect(UnlockDetectorStatus.fromString('LOCKED'),
          UnlockDetectorStatus.locked);
      expect(UnlockDetectorStatus.fromString('UNLOCKED'),
          UnlockDetectorStatus.unlocked);
      expect(UnlockDetectorStatus.fromString('BACKGROUND'),
          UnlockDetectorStatus.background);
      expect(UnlockDetectorStatus.fromString('FOREGROUND'),
          UnlockDetectorStatus.foreground);
      expect(UnlockDetectorStatus.fromString('IDLE'), UnlockDetectorStatus.idle);
      expect(UnlockDetectorStatus.fromString('SCREEN_ON'),
          UnlockDetectorStatus.screenOn);
    });

    test('fromString falls back to unknown', () {
      expect(UnlockDetectorStatus.fromString('NOPE'),
          UnlockDetectorStatus.unknown);
      expect(UnlockDetectorStatus.fromString(''), UnlockDetectorStatus.unknown);
    });

    test('online means foreground only', () {
      expect(UnlockDetectorStatus.foreground.isOnline, isTrue);
      for (final status in UnlockDetectorStatus.values) {
        if (status != UnlockDetectorStatus.foreground) {
          expect(status.isOnline, isFalse, reason: '${status.name} is online');
        }
      }
    });

    test('offline covers background and locked, but not idle', () {
      expect(UnlockDetectorStatus.background.isOffline, isTrue);
      expect(UnlockDetectorStatus.locked.isOffline, isTrue);
      expect(UnlockDetectorStatus.idle.isOffline, isFalse);
      expect(UnlockDetectorStatus.idle.isIdle, isTrue);
    });
  });

  group('UnlockDetectorException', () {
    test('toString includes the cause when there is one', () {
      expect(const UnlockDetectorException('boom').toString(),
          'UnlockDetectorException: boom');
      expect(const UnlockDetectorException('boom', 'cause').toString(),
          'UnlockDetectorException: boom (cause)');
    });
  });

  group('platform description', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('names the detection available on each platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(UnlockDetector.isAndroid, isTrue);
      expect(UnlockDetector.getPlatformInfo(), startsWith('Android'));

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(UnlockDetector.isIOS, isTrue);
      expect(UnlockDetector.getPlatformInfo(), startsWith('iOS'));

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(UnlockDetector.getPlatformInfo(), startsWith('Web / desktop'));
    });
  });

  group('UnlockDetector', () {
    const methodChannel = MethodChannel('unlock_detector');
    const eventChannel = EventChannel('unlock_detector_stream');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final methodLog = <MethodCall>[];
    MockStreamHandlerEventSink? nativeSink;
    Object? Function(MethodCall call)? responder;

    setUp(() {
      methodLog.clear();
      nativeSink = null;
      responder = null;

      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        methodLog.add(call);
        final respond = responder;
        if (respond != null) return respond(call);
        return call.method == 'is_device_locked' ? false : 'ok';
      });
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) => nativeSink = events,
          onCancel: (arguments) => nativeSink = null,
        ),
      );
    });

    tearDown(() async {
      await UnlockDetector.dispose();
      messenger.setMockMethodCallHandler(methodChannel, null);
      messenger.setMockStreamHandler(eventChannel, null);
    });

    /// Initializes and lets the event-channel `listen` message land, so
    /// `nativeSink` is available to the test.
    Future<void> init({Duration? idleTimeout}) async {
      await UnlockDetector.initialize(idleTimeout: idleTimeout);
      await pumpEventQueue();
    }

    Future<void> emitNative(Object event) async {
      nativeSink!.success(event);
      await pumpEventQueue();
    }

    test('shakes hands with the native side on initialize and dispose',
        () async {
      await init();
      expect(UnlockDetector.isInitialized, isTrue);
      expect(methodLog.map((c) => c.method), contains('detect_on'));

      await UnlockDetector.dispose();
      expect(UnlockDetector.isInitialized, isFalse);
      expect(UnlockDetector.currentStatus, isNull);
      expect(methodLog.map((c) => c.method), contains('detect_off'));
    });

    test('initializes only once', () async {
      await init();
      await init();
      expect(methodLog.where((c) => c.method == 'detect_on'), hasLength(1));
    });

    test('initializes on platforms with no native implementation', () async {
      messenger.setMockMethodCallHandler(methodChannel, null);
      await UnlockDetector.initialize();
      expect(UnlockDetector.isInitialized, isTrue);
    });

    test('turns an Android string event into a status', () async {
      await init();
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);

      await emitNative('LOCKED');
      await subscription.cancel();

      expect(seen, [UnlockDetectorStatus.locked]);
      expect(UnlockDetector.currentStatus, UnlockDetectorStatus.locked);
    });

    test('turns an iOS map event into a status', () async {
      await init();
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);

      await emitNative(
        <String, Object?>{'event': 'UNLOCKED', 'type': 'data_protection'},
      );
      await subscription.cancel();

      expect(seen, [UnlockDetectorStatus.unlocked]);
    });

    test('drops repeated and unrecognized events', () async {
      await init();
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);

      await emitNative('LOCKED');
      await emitNative('LOCKED');
      await emitNative('NOT_A_STATUS');
      await subscription.cancel();

      expect(seen, [UnlockDetectorStatus.locked]);
    });

    test('a failed initialize leaves no listener behind', () async {
      responder = (call) {
        if (call.method == 'detect_on') {
          throw PlatformException(code: 'BOOM', message: 'no');
        }
        return 'ok';
      };

      await expectLater(
        UnlockDetector.initialize(),
        throwsA(isA<UnlockDetectorException>()),
      );
      expect(UnlockDetector.isInitialized, isFalse);

      // The retry must not end up with two subscriptions on the event channel,
      // which would deliver every native event twice.
      responder = null;
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);
      await init();
      await emitNative('LOCKED');
      await subscription.cancel();

      expect(seen.where((s) => s == UnlockDetectorStatus.locked), hasLength(1));
    });

    test('emits idle after the timeout and leaves idle on activity', () async {
      // Generous window: the assertions below must not race the timer that
      // reportActivity re-arms.
      await init(idleTimeout: const Duration(milliseconds: 250));
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);

      UnlockDetector.reportActivity();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(UnlockDetector.currentStatus, UnlockDetectorStatus.idle);

      // Checked synchronously: reportActivity leaves idle immediately, but it
      // also arms a fresh timer that any await here could let fire.
      UnlockDetector.reportActivity();
      expect(UnlockDetector.currentStatus, UnlockDetectorStatus.foreground);

      await pumpEventQueue();
      await subscription.cancel();
      expect(seen, contains(UnlockDetectorStatus.idle));
    });

    test('reportActivity after dispose does not schedule an idle', () async {
      await init(idleTimeout: const Duration(milliseconds: 60));
      final seen = <UnlockDetectorStatus>[];
      final subscription = UnlockDetector.stream.listen(seen.add);

      await UnlockDetector.dispose();
      UnlockDetector.reportActivity();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await subscription.cancel();

      expect(seen, isNot(contains(UnlockDetectorStatus.idle)));
    });

    test('isDeviceLocked returns the native answer', () async {
      responder = (call) => call.method == 'is_device_locked' ? true : 'ok';
      expect(await UnlockDetector.isDeviceLocked(), isTrue);
    });

    test('isDeviceLocked is false when the platform call fails', () async {
      responder = (call) => throw PlatformException(code: 'NOPE');
      expect(await UnlockDetector.isDeviceLocked(), isFalse);
    });

    test('activityDetector wraps its child in a pointer listener', () {
      final widget = UnlockDetector.activityDetector(child: const SizedBox());
      expect(widget, isA<Listener>());
      expect((widget as Listener).child, isA<SizedBox>());
    });
  });
}
