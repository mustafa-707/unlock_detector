/// Detects device lock/unlock, app foreground/background, idle and screen
/// state — for user online/offline presence.
///
/// Platform coverage:
/// - **foreground / background / idle** — all platforms. On Android and iOS
///   this tracks the app lifecycle; on web and desktop it tracks window
///   focus/blur (a focused window is `foreground`, a blurred or minimized
///   one is `background`).
/// - **locked / unlocked / screenOn** — Android and iOS only.
library;

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Presence and device statuses emitted by [UnlockDetector].
enum UnlockDetectorStatus {
  /// Device screen was locked — user is OFFLINE.
  locked('LOCKED'),

  /// Device was unlocked — user authenticated.
  unlocked('UNLOCKED'),

  /// App moved to the background — user is OFFLINE.
  background('BACKGROUND'),

  /// App is in the foreground — user is ONLINE.
  foreground('FOREGROUND'),

  /// App is in the foreground but the user has been inactive
  /// (see `idleTimeout` in [UnlockDetector.initialize]).
  idle('IDLE'),

  /// Device screen turned on (it may still be locked). Android only.
  screenOn('SCREEN_ON'),

  /// Unknown or unrecognized status.
  unknown('UNKNOWN');

  final String value;
  const UnlockDetectorStatus(this.value);

  /// User is actively using the app.
  bool get isOnline => this == foreground;

  /// User is not using the app (background or device locked).
  bool get isOffline => this == background || this == locked;

  /// App is open but the user has been inactive.
  bool get isIdle => this == idle;

  /// Device is locked.
  bool get isLocked => this == locked;

  /// Device was just unlocked.
  bool get isUnlocked => this == unlocked;

  /// App is in the background.
  bool get isBackground => this == background;

  /// App is in the foreground.
  bool get isForeground => this == foreground;

  /// Device screen is on.
  bool get isScreenOn => this == screenOn;

  /// Converts a platform string to the matching enum value.
  static UnlockDetectorStatus fromString(String value) {
    return UnlockDetectorStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => UnlockDetectorStatus.unknown,
    );
  }
}

/// Thrown when an [UnlockDetector] operation fails.
class UnlockDetectorException implements Exception {
  final String message;
  final dynamic originalError;

  const UnlockDetectorException(this.message, [this.originalError]);

  @override
  String toString() => 'UnlockDetectorException: $message'
      '${originalError != null ? ' ($originalError)' : ''}';
}

/// Detects device and app presence state.
///
/// Static API — call [initialize] once, listen to [stream], call [dispose]
/// when finished:
///
/// ```dart
/// await UnlockDetector.initialize();
/// final sub = UnlockDetector.stream.listen((status) {
///   if (status.isOnline) { /* user active */ }
/// });
/// // ...
/// await sub.cancel();
/// await UnlockDetector.dispose();
/// ```
class UnlockDetector {
  /// Const constructor — this class only exposes static members.
  const UnlockDetector();

  static const MethodChannel _methodChannel = MethodChannel('unlock_detector');
  static const EventChannel _eventChannel = EventChannel(
    'unlock_detector_stream',
  );

  static bool _isInitialized = false;
  static StreamSubscription? _nativeSubscription;
  static AppLifecycleListener? _lifecycleListener;
  static final _controller = StreamController<UnlockDetectorStatus>.broadcast();
  static UnlockDetectorStatus? _currentStatus;

  static Duration? _idleTimeout;
  static Timer? _idleTimer;

  /// Registrant required by the Dart-only (web / desktop) platform
  /// declarations. No-op — presence detection there is plain Dart.
  static void registerWith() {}

  /// Whether [initialize] has been called.
  static bool get isInitialized => _isInitialized;

  /// The most recently observed status, or `null` before the first event
  /// (or after [dispose]).
  ///
  /// [stream] is a broadcast stream that only emits on change — read this to
  /// obtain the current state synchronously.
  static UnlockDetectorStatus? get currentStatus => _currentStatus;

  /// Whether the current platform is Android.
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Whether the current platform is iOS.
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Broadcast stream of presence changes. Call [initialize] before listening.
  static Stream<UnlockDetectorStatus> get stream => _controller.stream;

  /// Starts detection. Safe to call multiple times — initializes only once.
  ///
  /// [idleTimeout] — when set, the status becomes [UnlockDetectorStatus.idle]
  /// after the app has been in the foreground for this long without a
  /// [reportActivity] call. Leave `null` to disable idle detection. When using
  /// it, feed interaction via [reportActivity] or wrap your app in
  /// [activityDetector].
  ///
  /// Throws [UnlockDetectorException] if initialization fails.
  static Future<void> initialize({Duration? idleTimeout}) async {
    if (_isInitialized) {
      log('[unlock_detector] Already initialized');
      return;
    }
    _idleTimeout = idleTimeout;

    try {
      // Foreground / background — plain Dart, works on every platform.
      _lifecycleListener = AppLifecycleListener(
        onStateChange: _onLifecycleStateChange,
      );

      // Native lock / unlock / screen events — Android and iOS only.
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) => _emit(_parseStatus(event)),
        onError: (error) {
          log('[unlock_detector] Stream error: $error');
          _controller.addError(
            UnlockDetectorException('Stream error', error),
          );
        },
      );

      // Handshake with the native side (absent on web / desktop).
      try {
        await _methodChannel.invokeMethod('detect_on');
      } on MissingPluginException {
        // No native implementation here — lifecycle + idle still work.
      }

      _isInitialized = true;

      // Emit the current lifecycle state immediately.
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null) {
        _onLifecycleStateChange(state);
      }
    } on PlatformException catch (e) {
      throw UnlockDetectorException('Failed to initialize: ${e.message}', e);
    } catch (e) {
      throw UnlockDetectorException('Failed to initialize', e);
    }
  }

  /// Stops detection and releases resources. Safe to call multiple times.
  static Future<void> dispose() async {
    if (!_isInitialized) {
      log('[unlock_detector] Already disposed or never initialized');
      return;
    }

    _idleTimer?.cancel();
    _idleTimer = null;
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _currentStatus = null;
    _isInitialized = false;

    try {
      await _methodChannel.invokeMethod('detect_off');
    } on MissingPluginException {
      // No native implementation here.
    } catch (e) {
      log('[unlock_detector] Failed to call detect_off: $e');
    }
    log('[unlock_detector] Disposed');
  }

  /// Reports user interaction, resetting the idle timer.
  ///
  /// Only relevant when [initialize] was given an `idleTimeout`. Call it from
  /// your input handling, or use [activityDetector] to wire it automatically.
  static void reportActivity() {
    if (_idleTimeout == null) return;
    if (_currentStatus == UnlockDetectorStatus.idle) {
      _emit(UnlockDetectorStatus.foreground);
    }
    _armIdleTimer();
  }

  /// Wraps [child] so any pointer interaction calls [reportActivity].
  ///
  /// Place it above your app content when using idle detection:
  /// ```dart
  /// UnlockDetector.activityDetector(child: const MyApp());
  /// ```
  static Widget activityDetector({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => reportActivity(),
      onPointerSignal: (_) => reportActivity(),
      child: child,
    );
  }

  /// Whether the device is currently locked.
  ///
  /// Android: reliable via `KeyguardManager`. iOS: best-effort (data
  /// protection). Web and desktop: always `false`.
  static Future<bool> isDeviceLocked() async {
    try {
      return await _methodChannel.invokeMethod<bool>('is_device_locked') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// A human-readable description of detection behavior on this platform.
  static String getPlatformInfo() {
    if (isAndroid) {
      return 'Android: foreground/background, idle, and lock/unlock/screen-on '
          'detection.';
    } else if (isIOS) {
      return 'iOS: foreground/background and idle detection; lock/unlock via '
          'data-protection APIs (works while the app is active).';
    }
    return 'Web / desktop: window focus/blur (foreground/background) and idle '
        'detection.';
  }

  // --- internals ---

  /// Whether the app runs on web or a desktop OS, where presence is a matter
  /// of window focus rather than device lock.
  static bool get _isDesktopOrWeb =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  static void _onLifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Window focused / app in the foreground.
        _emit(UnlockDetectorStatus.foreground);
        _armIdleTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // App hidden / window minimized.
        _idleTimer?.cancel();
        _emit(UnlockDetectorStatus.background);
      case AppLifecycleState.inactive:
        // On web and desktop, 'inactive' means the window lost focus — treat
        // it as background. On mobile it is only a brief transition (incoming
        // call, app switcher, control center), so it is ignored there.
        if (_isDesktopOrWeb) {
          _idleTimer?.cancel();
          _emit(UnlockDetectorStatus.background);
        }
    }
  }

  static void _armIdleTimer() {
    final timeout = _idleTimeout;
    if (timeout == null) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(timeout, () => _emit(UnlockDetectorStatus.idle));
  }

  static void _emit(UnlockDetectorStatus status) {
    if (status == UnlockDetectorStatus.unknown || status == _currentStatus) {
      return;
    }
    _currentStatus = status;
    log('[unlock_detector] Status changed: ${status.name}');
    _controller.add(status);
  }

  /// Parses a native event (iOS map or Android string) into a status.
  static UnlockDetectorStatus _parseStatus(dynamic event) {
    if (event is Map) {
      return UnlockDetectorStatus.fromString(event['event']?.toString() ?? '');
    } else if (event is String) {
      return UnlockDetectorStatus.fromString(event);
    }
    log('[unlock_detector] Unknown event format: $event');
    return UnlockDetectorStatus.unknown;
  }
}
