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

  /// True from the moment [initialize] starts wiring listeners until
  /// [_releaseResources] tears them down. Gates [_emit] so nothing is
  /// delivered after teardown, while still letting native events that arrive
  /// during initialization through.
  static bool _active = false;
  static StreamSubscription? _nativeSubscription;
  static AppLifecycleListener? _lifecycleListener;
  static final _controller = StreamController<UnlockDetectorStatus>.broadcast();
  static UnlockDetectorStatus? _currentStatus;

  static Duration? _idleTimeout;
  static Timer? _idleTimer; // mobile / web: in-app inactivity timer
  static Timer? _idlePollTimer; // desktop: OS system-idle poll

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
  /// after this much inactivity. On desktop (macOS, Windows, Linux) the idle
  /// time is read system-wide from the OS automatically. On mobile and web,
  /// feed interaction via [reportActivity] or wrap your app in
  /// [activityDetector]. Leave `null` to disable idle detection.
  ///
  /// Throws [UnlockDetectorException] if initialization fails.
  static Future<void> initialize({Duration? idleTimeout}) async {
    if (_isInitialized) {
      log('[unlock_detector] Already initialized');
      return;
    }
    _idleTimeout = idleTimeout;
    _active = true;

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

      // On desktop, idle is read system-wide from the OS.
      if (_idleTimeout != null && _isDesktop) {
        _startIdlePolling();
      }
    } on PlatformException catch (e) {
      await _releaseResources();
      throw UnlockDetectorException('Failed to initialize: ${e.message}', e);
    } catch (e) {
      await _releaseResources();
      throw UnlockDetectorException('Failed to initialize', e);
    }
  }

  /// Stops detection and releases resources. Safe to call multiple times.
  ///
  /// [stream] itself stays open, so the detector can be re-[initialize]d later
  /// without existing listeners being dropped.
  static Future<void> dispose() async {
    if (!_isInitialized) {
      log('[unlock_detector] Already disposed or never initialized');
      return;
    }

    await _releaseResources();

    try {
      await _methodChannel.invokeMethod('detect_off');
    } on MissingPluginException {
      // No native implementation here.
    } catch (e) {
      log('[unlock_detector] Failed to call detect_off: $e');
    }
    log('[unlock_detector] Disposed');
  }

  /// Tears down every listener and timer and clears the cached state.
  ///
  /// Shared by [dispose] and by [initialize]'s error path, so a failed
  /// initialization cannot leave a half-wired listener behind that the next
  /// [initialize] call would then duplicate.
  static Future<void> _releaseResources() async {
    _active = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    _stopIdlePolling();
    final subscription = _nativeSubscription;
    _nativeSubscription = null;
    await subscription?.cancel();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _currentStatus = null;
    _idleTimeout = null;
    _isInitialized = false;
  }

  /// Reports user interaction, resetting the idle timer.
  ///
  /// Only relevant when [initialize] was given an `idleTimeout`. Call it from
  /// your input handling, or use [activityDetector] to wire it automatically.
  static void reportActivity() {
    if (!_active || _idleTimeout == null) return;
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

  /// Whether the app runs on a desktop OS (not web), where idle time can be
  /// read system-wide from the operating system.
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static void _onLifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Window focused / app in the foreground.
        _emit(UnlockDetectorStatus.foreground);
        _armIdleTimer();
        _startIdlePolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // App hidden / window minimized.
        _idleTimer?.cancel();
        _stopIdlePolling();
        _emit(UnlockDetectorStatus.background);
      case AppLifecycleState.inactive:
        // On web and desktop, 'inactive' means the window lost focus — treat
        // it as background. On mobile it is only a brief transition (incoming
        // call, app switcher, control center), so it is ignored there.
        if (_isDesktopOrWeb) {
          _idleTimer?.cancel();
          _stopIdlePolling();
          _emit(UnlockDetectorStatus.background);
        }
    }
  }

  static void _armIdleTimer() {
    final timeout = _idleTimeout;
    // Desktop uses OS-level idle polling instead of an in-app timer.
    if (timeout == null || _isDesktop) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(timeout, () => _emit(UnlockDetectorStatus.idle));
  }

  /// Starts polling the OS for system-wide idle time (desktop only).
  ///
  /// Polling runs only while the window has focus: asking the OS for idle time
  /// while the app is in the background tells us nothing new — the status is
  /// already `background` — and the periodic wake-ups cost battery.
  static void _startIdlePolling() {
    final timeout = _idleTimeout;
    if (timeout == null || !_isDesktop) return;
    _idlePollTimer?.cancel();
    final interval = timeout < const Duration(seconds: 60)
        ? const Duration(seconds: 5)
        : const Duration(seconds: 20);
    _idlePollTimer = Timer.periodic(interval, (_) => _pollSystemIdle());
    _pollSystemIdle();
  }

  /// Stops the desktop idle poll — on focus loss and on teardown.
  static void _stopIdlePolling() {
    _idlePollTimer?.cancel();
    _idlePollTimer = null;
  }

  /// Compares OS idle time against [_idleTimeout] and emits `idle` /
  /// `foreground` accordingly. Only acts while the app is in the foreground.
  static Future<void> _pollSystemIdle() async {
    final timeout = _idleTimeout;
    if (timeout == null) return;
    final idleSeconds = await _systemIdleSeconds();
    // The await above can outlive dispose() — drop late results.
    if (!_active) return;
    final isIdleNow = idleSeconds >= timeout.inSeconds;
    if (isIdleNow && _currentStatus == UnlockDetectorStatus.foreground) {
      _emit(UnlockDetectorStatus.idle);
    } else if (!isIdleNow && _currentStatus == UnlockDetectorStatus.idle) {
      _emit(UnlockDetectorStatus.foreground);
    }
  }

  /// Seconds since the last system-wide input, from the native side.
  static Future<int> _systemIdleSeconds() async {
    try {
      return await _methodChannel.invokeMethod<int>(
            'get_system_idle_seconds',
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static void _emit(UnlockDetectorStatus status) {
    if (!_active ||
        status == UnlockDetectorStatus.unknown ||
        status == _currentStatus) {
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
