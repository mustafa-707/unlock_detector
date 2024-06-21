library unlock_detector;

import 'dart:developer';

import 'package:flutter/services.dart';

class UnlockDetector {
  static const MethodChannel _methodChannel = MethodChannel('unlock_detector');
  static const EventChannel _eventChannel = EventChannel(
    'unlock_detector_stream',
  );

  Stream<String>? _lockUnlockStream;

  // Singleton pattern
  static final UnlockDetector _instance = UnlockDetector._internal();

  factory UnlockDetector() {
    return _instance;
  }

  UnlockDetector._internal() {
    _lockUnlockStream = _eventChannel.receiveBroadcastStream().map(
          (event) => event.toString(),
        );
  }

  // Start detection
  Future<void> startDetection() async {
    try {
      await _methodChannel.invokeMethod('detect_on');
    } on PlatformException catch (e) {
      log("[unlock_detector] :: Failed to start detection: '${e.message}'.");
    }
  }

  Stream<String>? get lockUnlockStream => _lockUnlockStream;
}
