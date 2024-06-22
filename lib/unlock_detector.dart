library unlock_detector;

import 'dart:developer';

import 'package:flutter/services.dart';

enum UnlockDetectorStatus {
  locked("LOCKED"),
  unlocked("UNLOCKED"),

  /// Screen turned on only on Android
  screenOn("SCREEN_ON"),
  unknown("UNKNOWN");

  final String name;
  const UnlockDetectorStatus(this.name);

  // And other members too.
  bool get isLocked => index == locked.index;
  bool get isUnlocked => index == unlocked.index;
  bool get isScreenOn => index == screenOn.index;
}

class UnlockDetector {
  static const MethodChannel _methodChannel = MethodChannel('unlock_detector');
  static const EventChannel _eventChannel = EventChannel(
    'unlock_detector_stream',
  );

  Stream<UnlockDetectorStatus>? _lockUnlockStream;

  // Singleton pattern
  static final UnlockDetector _instance = UnlockDetector._internal();

  factory UnlockDetector() {
    return _instance;
  }

  UnlockDetector._internal() {
    _lockUnlockStream = _eventChannel.receiveBroadcastStream().map(
          (event) => switch (event.toString()) {
            "LOCKED" => UnlockDetectorStatus.locked,
            "UNLOCKED" => UnlockDetectorStatus.unlocked,
            "SCREEN_ON" => UnlockDetectorStatus.screenOn,
            _ => UnlockDetectorStatus.unknown
          },
        );
  }

  /// it must to be called before start detection
  Future<void> initalize() async {
    try {
      await _methodChannel.invokeMethod('detect_on');
    } on PlatformException catch (e) {
      log("[unlock_detector] :: Failed to initalize: '${e.message}'.");
    } catch (e) {
      log("[unlock_detector] :: Failed to initalize: '$e'.");
    }
  }

  /// stream of lock/unlock events
  Stream<UnlockDetectorStatus>? get lockUnlockStream => _lockUnlockStream;
}
