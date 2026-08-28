# CHANGES

## 1.4.0

**Breaking:** the minimum supported version is now Flutter 3.44 / Dart 3.12,
and your app must build with Android Gradle Plugin 9 or newer. Stay on `1.3.x`
if you cannot move yet.

- **Migrated to built-in Kotlin** ([#5]) — the plugin no longer applies the
  Kotlin Gradle Plugin. From Flutter 3.47, an app using a plugin that applies
  KGP prints a `flutter doctor` warning, and future Flutter versions fail the
  build outright. Kotlin now comes from AGP's built-in support.
- The plugin's `buildscript` block is gone with it. It pinned its own AGP and
  Kotlin versions onto the consuming app's build classpath, where the highest
  version across the build wins — so the plugin could quietly force an AGP
  upgrade on an app that never asked for one. Both now come from the app.
- The example app moves to AGP 9.3.2, Gradle 9.7.1, Kotlin 2.4.10 and
  `android.builtInKotlin=true`.
- Note for apps: AGP 9's built-in Kotlin resolves KGP 2.2.10, below Flutter
  3.47's 2.2.20 minimum, so the build fails until you declare a newer KGP in
  your app's `settings.gradle` with `apply false`. See the README.

[#5]: https://github.com/mustafa-707/unlock_detector/issues/5

## 1.3.0

### Fixed

- **Idle could fire after `dispose()`** — `dispose()` now clears the idle
  timeout, and every status emission is gated on the detector being active, so
  a late `reportActivity()` or an in-flight OS idle poll can no longer push a
  status onto the stream after teardown.
- **A failed `initialize()` leaked its listeners** — the lifecycle listener and
  the native event subscription are now torn down on the error path. Retrying
  after a failure previously left a second subscription behind, which delivered
  every native event twice.
- **Desktop idle polling ran in the background** — the OS idle poll now stops
  when the window loses focus and restarts when it regains focus, instead of
  waking every few seconds for a status that cannot change.
- **Linux: idle detection did not work on Wayland.** The X11 screensaver
  extension only sees XWayland input, so the reported idle time never grew.
  The compositor is now queried over D-Bus (GNOME/Mutter, and the freedesktop
  screensaver interface used by KDE), with X11 kept as the source on X11
  sessions. The X11 display is also opened once instead of per poll.
- **macOS:** replaced the deprecated `kIOMasterPortDefault` with
  `kIOMainPortDefault` on macOS 12+, and read `HIDIdleTime` through `NSNumber`
  so a differently-sized `CFNumber` no longer silently reports zero idle time.
- **Android:** the event sink is released when the engine detaches, and the
  `KeyguardManager` lookup uses a checked cast.
- **`pubspec.yaml` declared `flutter: ">=3.0.0"`** but the plugin uses
  `AppLifecycleListener` and `AppLifecycleState.hidden`; the constraint is now
  `>=3.13.0` (Dart `>=3.1.0`), so an incompatible version fails at resolve time
  rather than at compile time.

### Changed

- The Android package moved from `com.example.unlock_detector` to
  `com.mustafa707.unlock_detector`. Flutter registers the plugin automatically,
  so no app-side change is needed unless you referenced the class by name.

### Added

- A unit-test suite covering status parsing, the initialize/dispose handshake,
  event de-duplication, idle behavior, and the teardown fixes above.
- The example app now demonstrates `idleTimeout`, `activityDetector` and
  `isDeviceLocked`, names the real platform it runs on (it previously reported
  every non-Android platform as iOS), covers the `idle` and `screenOn`
  statuses, and follows the light/dark theme instead of hard-coding white.

## 1.2.0

- **Native desktop support** — macOS, Windows and Linux now ship native plugin
  code with **system-wide idle detection**: when `initialize()` is given an
  `idleTimeout`, the `idle` status follows the OS idle time (time since any
  keyboard/mouse input) — no `reportActivity()` needed on desktop.
  - macOS: IOKit HID idle time · Windows: `GetLastInputInfo` · Linux: the X11
    screensaver extension (needs `libxss-dev`; X11 sessions).
- All six platforms are now declared with native implementations in `pubspec.yaml`.

## 1.1.1

- Web & desktop: window **blur** (lost focus) is now reported as `background`
  and window **focus** as `foreground` — previously a blurred-but-visible
  window was missed. Mobile behavior is unchanged.

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
