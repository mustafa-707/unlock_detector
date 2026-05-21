# CHANGES

## 1.1.0

- **Web & desktop support** — foreground/background and idle now work on web,
  macOS, Windows and Linux (driven by the Flutter app lifecycle).
- **Idle detection** — pass `idleTimeout` to `initialize()` to receive an
  `idle` status when the user is inactive; feed interaction via
  `reportActivity()` or wrap your app in `UnlockDetector.activityDetector()`.
- **`isDeviceLocked()`** — one-shot lock-state query (Android reliable via
  `KeyguardManager`, iOS best-effort).
- **`currentStatus`** — read the last status synchronously; `initialize()` now
  also emits the current state immediately.
- New `screenOn` status from Android `ACTION_SCREEN_ON`.
- Add Swift Package Manager support on iOS; CocoaPods still works.
- Foreground/background detection moved to the Flutter app lifecycle (pure
  Dart) — same events, fewer moving parts, and it works on every platform.
- Android: dropped the unused `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` and
  `DISABLE_KEYGUARD` permissions; Kotlin 2.3.21, AGP 8.11.1, Gradle 8.14,
  `compileSdk` 36.
- iOS: deployment target 13.0; added a privacy manifest; observers removed on
  deinit; fixed podspec metadata.
- Removed the stale Android unit test; added `flutter_lints`; shorter README.

## 1.0.0

- detect more state new isOnline , isOffline flags
- upgrade versions
- update `Readme` with new names changes

## 0.1.0

- solve `iOS` not working reported by kmiller issue#1
- make initializing direct when listen to stream
- update `Readme` with new names changes

## 0.0.6

- change calls names `startDetection` it changed to `initialize`
- change calls names `lockUnlockStream` it changed to `stream`
- update `Readme` with new names changes

## 0.0.5

- update `changelog` file.

## 0.0.4

- make `minAndroidSdk` to 19 instead of 21.
- Add Enum Named `UnlockDetectorStatus` as return value.

## 0.0.3

- update dart version to 3.0.0.

## 0.0.2

- update `readme` file.

## 0.0.1

- release the package.
