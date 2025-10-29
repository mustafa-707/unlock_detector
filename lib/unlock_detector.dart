/// A simple utility to detect if the user is actively using the app (online/offline).
///
/// This package tracks 4 essential statuses:
/// - **FOREGROUND**: User is actively using the app (ONLINE)
/// - **BACKGROUND**: User switched away from the app (OFFLINE)
/// - **LOCKED**: Device is locked, user definitely not using app (OFFLINE)
/// - **UNLOCKED**: Device unlocked, user may return to app
///
/// **Platform Support:**
/// - **Android**: Full support for all statuses
/// - **iOS**: Limited - detects BACKGROUND/FOREGROUND and LOCKED/UNLOCKED when app is active
///
/// **Usage Example:**
/// ```dart
/// await UnlockDetector.initialize();
///
/// UnlockDetector.stream.listen((status) {
///   if (status.isOnline) {
///     print('User is actively using the app');
///     // Update user's online status in your backend
///     api.updateUserStatus(userId, online: true);
///   } else if (status.isOffline) {
///     print('User is not using the app');
///     // Mark user as offline in your backend
///     api.updateUserStatus(userId, online: false);
///   }
/// });
///
/// // Clean up when done
/// await UnlockDetector.dispose();
/// ```
library unlock_detector;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Essential statuses for determining if user is online/offline.
enum UnlockDetectorStatus {
  /// Device is locked - user is definitely OFFLINE.
  locked("LOCKED"),

  /// Device was unlocked - user authenticated.
  unlocked("UNLOCKED"),

  /// App went to background - user is OFFLINE.
  background("BACKGROUND"),

  /// App came to foreground - user is ONLINE.
  foreground("FOREGROUND"),

  /// Unknown or unrecognized status.
  unknown("UNKNOWN");

  final String value;
  const UnlockDetectorStatus(this.value);

  /// True when user is actively using the app (online).
  ///
  /// Returns true only when status is [foreground].
  bool get isOnline => this == foreground;

  /// True when user is not using the app (offline).
  ///
  /// Returns true when status is [background] or [locked].
  bool get isOffline => this == background || this == locked;

  /// True when the device is locked.
  bool get isLocked => this == locked;

  /// True when the device was unlocked.
  bool get isUnlocked => this == unlocked;

  /// True when app is in background.
  bool get isBackground => this == background;

  /// True when app is in foreground.
  bool get isForeground => this == foreground;

  /// Converts a string value to the corresponding enum value.
  static UnlockDetectorStatus fromString(String value) {
    return UnlockDetectorStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => UnlockDetectorStatus.unknown,
    );
  }
}

/// Exception thrown when unlock detector operations fail.
class UnlockDetectorException implements Exception {
  final String message;
  final dynamic originalError;

  const UnlockDetectorException(this.message, [this.originalError]);

  @override
  String toString() =>
      'UnlockDetectorException: $message${originalError != null ? ' ($originalError)' : ''}';
}

/// Simple detector for tracking if user is actively using the app.
///
/// This class provides a static API to monitor app and device state changes.
/// It emits 4 essential statuses:
/// - [UnlockDetectorStatus.foreground]: User is actively using the app
/// - [UnlockDetectorStatus.background]: User switched to another app
/// - [UnlockDetectorStatus.locked]: Device screen was locked
/// - [UnlockDetectorStatus.unlocked]: Device screen was unlocked
///
/// **Important Notes:**
/// - You must call [initialize] before listening to [stream]
/// - Always call [dispose] when you're done to clean up resources
/// - Use [isOnline] and [isOffline] getters on statuses for simple checks
///
/// **Example:**
/// ```dart
/// // Initialize once at app startup
/// await UnlockDetector.initialize();
///
/// // Listen to status changes
/// final subscription = UnlockDetector.stream.listen((status) {
///   if (status.isOnline) {
///     // User is actively using your app
///     myBackendService.setUserOnline();
///   } else if (status.isOffline) {
///     // User left the app or locked their device
///     myBackendService.setUserOffline();
///   }
/// });
///
/// // Later, clean up
/// await subscription.cancel();
/// await UnlockDetector.dispose();
/// ```
class UnlockDetector {
  static const MethodChannel _methodChannel = MethodChannel('unlock_detector');
  static const EventChannel _eventChannel =
      EventChannel('unlock_detector_stream');

  static bool _isInitialized = false;
  static StreamSubscription? _internalSubscription;
  static final _controller = StreamController<UnlockDetectorStatus>.broadcast();

  /// Whether the detector has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Whether the current platform is Android.
  static bool get isAndroid => Platform.isAndroid;

  /// Whether the current platform is iOS.
  static bool get isIOS => Platform.isIOS;

  /// Stream of online/offline status changes.
  ///
  /// Listen to this stream to know when the user is actively using the app
  /// (FOREGROUND) or not (BACKGROUND/LOCKED).
  ///
  /// **You must call [initialize] before listening to this stream.**
  ///
  /// Example:
  /// ```dart
  /// UnlockDetector.stream.listen((status) {
  ///   print('Status changed: ${status.name}');
  ///   if (status.isOnline) {
  ///     print('User is using the app');
  ///   }
  /// });
  /// ```
  static Stream<UnlockDetectorStatus> get stream => _controller.stream;

  /// Initialize the detector.
  ///
  /// This method sets up the platform channels and starts listening for
  /// lock/unlock and app lifecycle events from the native side.
  ///
  /// It is safe to call this multiple times - it will only initialize once.
  ///
  /// Throws [UnlockDetectorException] if initialization fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await UnlockDetector.initialize();
  ///   print('Detector initialized successfully');
  /// } catch (e) {
  ///   print('Failed to initialize: $e');
  /// }
  /// ```
  static Future<void> initialize() async {
    if (_isInitialized) {
      log('[unlock_detector] Already initialized');
      return;
    }

    try {
      // Start listening to the platform event stream
      _internalSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          final status = _parseStatus(event);
          log('[unlock_detector] Status changed: ${status.name}');
          _controller.add(status);
        },
        onError: (error) {
          log('[unlock_detector] Stream error: $error');
          _controller.addError(
            UnlockDetectorException('Stream error', error),
          );
        },
      );

      // Notify platform to start detection
      final result = await _methodChannel.invokeMethod('detect_on');
      log('[unlock_detector] $result');

      _isInitialized = true;
    } on PlatformException catch (e) {
      log('[unlock_detector] Platform exception: ${e.message}');
      throw UnlockDetectorException('Failed to initialize: ${e.message}', e);
    } catch (e) {
      log('[unlock_detector] Unexpected error: $e');
      throw UnlockDetectorException('Failed to initialize', e);
    }
  }

  /// Stop detection and clean up resources.
  ///
  /// This cancels all subscriptions and notifies the platform to stop
  /// detecting events. Call this when you no longer need lock/unlock detection,
  /// typically when disposing your app or when you're done monitoring status.
  ///
  /// It is safe to call this multiple times - it will only dispose once.
  ///
  /// Example:
  /// ```dart
  /// await UnlockDetector.dispose();
  /// print('Detector disposed');
  /// ```
  static Future<void> dispose() async {
    if (!_isInitialized) {
      log('[unlock_detector] Already disposed or never initialized');
      return;
    }

    try {
      // Cancel the internal subscription
      await _internalSubscription?.cancel();
      _internalSubscription = null;

      // Notify platform to stop detection (Android only)
      if (isAndroid) {
        try {
          await _methodChannel.invokeMethod('detect_off');
          log('[unlock_detector] Platform detection stopped');
        } catch (e) {
          log('[unlock_detector] Failed to call detect_off: $e');
        }
      }

      _isInitialized = false;
      log('[unlock_detector] Disposed successfully');
    } catch (e) {
      log('[unlock_detector] Error during disposal: $e');
    }
  }

  /// Parse the event from the platform into a [UnlockDetectorStatus].
  ///
  /// Handles both iOS (Map format) and Android (String format) responses.
  static UnlockDetectorStatus _parseStatus(dynamic event) {
    if (event is Map) {
      // iOS structured response: {event: "LOCKED", type: "data_protection"}
      final eventValue = event['event']?.toString() ?? '';
      return UnlockDetectorStatus.fromString(eventValue);
    } else if (event is String) {
      // Android simple string response: "LOCKED", "UNLOCKED", etc.
      return UnlockDetectorStatus.fromString(event);
    } else {
      log('[unlock_detector] Unknown event format: $event (${event.runtimeType})');
      return UnlockDetectorStatus.unknown;
    }
  }

  /// Get information about platform-specific behavior.
  ///
  /// Returns a human-readable string explaining how the detector works
  /// on the current platform.
  ///
  /// Example:
  /// ```dart
  /// print(UnlockDetector.getPlatformInfo());
  /// // Android: Tracks FOREGROUND/BACKGROUND (app state) and LOCKED/UNLOCKED (device state)
  /// ```
  static String getPlatformInfo() {
    if (isAndroid) {
      return 'Android: Tracks FOREGROUND/BACKGROUND (app state) and LOCKED/UNLOCKED (device state)';
    } else if (isIOS) {
      return 'iOS: Limited detection - BACKGROUND/FOREGROUND always work, LOCKED/UNLOCKED work when app is active';
    } else {
      return 'Platform not supported';
    }
  }

  /// Creates a new [UnlockDetector] instance.
  ///
  /// This class only exposes static members and does not require creating an
  /// instance. The constructor exists primarily for documentation purposes.
  const UnlockDetector();
}
