# unlock_detector

[![StandWithPalestine](https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg)](https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md) [![Pub Package](https://img.shields.io/pub/v/unlock_detector.svg)](https://pub.dev/packages/unlock_detector)

A Flutter plugin that detects **foreground/background**, **idle**, and device
**lock/unlock** — ideal for user online/offline presence in chat apps and
activity tracking.

## Status types

| Status | Meaning | User |
| ------ | ------- | ---- |
| `foreground` | App is active and visible | **online** |
| `idle` | App open but user inactive | *away* |
| `background` | User switched away | **offline** |
| `locked` | Device screen locked | **offline** |
| `unlocked` | Device just unlocked | *transitional* |
| `screenOn` | Screen turned on (Android) | *transitional* |

Helpers on each status: `isOnline`, `isOffline`, `isIdle`, `isLocked`,
`isUnlocked`, `isForeground`, `isBackground`, `isScreenOn`.

## Platform support

| Platform | foreground / background | idle | lock / unlock |
| -------- | :---: | :---: | :---: |
| Android | ✅ | ✅ in-app | ✅ + `screenOn` |
| iOS | ✅ | ✅ in-app | ✅ (data-protection APIs) |
| macOS · Windows · Linux | ✅ window focus | ✅ OS system-wide | — |
| Web | ✅ window focus | ✅ in-app | — |

On web and desktop, `foreground`/`background` reflect window **focus/blur**
(a focused window is online, blurred or minimized is offline) — there is no
device-lock concept there. On desktop, `idle` follows the **OS system-wide**
idle time; on mobile and web it follows in-app interaction (see below).

## Install

```yaml
dependencies:
  unlock_detector: ^1.1.0
```

iOS works with both CocoaPods and Swift Package Manager — no setup needed.

## Usage

```dart
import 'package:unlock_detector/unlock_detector.dart';

// Initialize once. Pass idleTimeout to enable idle detection.
await UnlockDetector.initialize(idleTimeout: const Duration(minutes: 5));

// Listen to status changes.
final sub = UnlockDetector.stream.listen((status) {
  if (status.isOnline) {
    // user is actively using the app
  } else if (status.isIdle) {
    // app open, user inactive
  } else if (status.isOffline) {
    // user left the app or locked the device
  }
});

// Read the latest status synchronously (null before the first event).
final now = UnlockDetector.currentStatus;

// One-shot lock check (Android reliable, iOS best-effort).
final locked = await UnlockDetector.isDeviceLocked();

// Clean up when done.
await sub.cancel();
await UnlockDetector.dispose();
```

### Idle detection

Pass `idleTimeout` to `initialize()` to get the `idle` status.

- **Desktop (macOS/Windows/Linux):** automatic — idle follows the OS
  system-wide idle time (any keyboard/mouse input). Nothing else to do.
- **Mobile & web:** feed in-app interaction so the timer can reset — call
  `UnlockDetector.reportActivity()` from your input handling, or wrap your app:

  ```dart
  runApp(UnlockDetector.activityDetector(child: const MyApp()));
  ```

Initialization failures throw `UnlockDetectorException`. Call
`UnlockDetector.getPlatformInfo()` for a description of platform behavior.

## Support

If this plugin helps you, consider supporting development:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)

## License

MIT — see [LICENSE](LICENSE).
