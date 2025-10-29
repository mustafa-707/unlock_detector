# Unlock Detector Plugin for Flutter

[![StandWithPalestine](https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/badges/StandWithPalestine.svg)](https://github.com/TheBSD/StandWithPalestine/blob/main/docs/README.md) [![Pub Package](https://img.shields.io/pub/v/unlock_detector.svg)](https://pub.dev/packages/unlock_detector)

A Flutter plugin to detect user online/offline status by monitoring device lock state and app lifecycle events. Perfect for chat apps, user presence systems, and any application needing accurate user activity tracking.

## Key Features

- � Track when users are actively using your app (online)
- � Detect when users go offline (background/locked)
- � Monitor device lock/unlock events
- � Track app foreground/background transitions
- ✨ Simple stream-based API
- 💪 Type-safe enum status values
- 🎯 Platform-specific optimizations

## Status Types

The plugin tracks four essential states:

| Status | Description | User State |
|--------|-------------|------------|
| `FOREGROUND` | App is active and visible | **ONLINE** |
| `BACKGROUND` | User switched to another app | **OFFLINE** |
| `LOCKED` | Device screen is locked | **OFFLINE** |
| `UNLOCKED` | Device was just unlocked | *Transitional* |

## Platform Support

| Android | iOS |
|---------|-----|
| ✅ Reliable detection of lock, unlock, and screen-on events | ✅ Limited detection using data protection APIs |
| ✅ Works in background while app is alive | ⚠️ Only works when app is active or recently backgrounded |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  unlock_detector: ^latest_version
```

## Usage

### 1. Initialize the Detector

Before using the detector, initialize it:

```dart
await UnlockDetector.initialize();
```

### 2. Listen for Status Changes

```dart
UnlockDetector.stream.listen((status) {
  if (status.isOnline) {
    print('User is actively using the app');
    // Update user's online status in your backend
    api.updateUserStatus(userId, online: true);
  } else if (status.isOffline) {
    print('User is not using the app');
    // Mark user as offline in your backend
    api.updateUserStatus(userId, online: false);
  }
});
```

### 3. Use Convenience Getters

```dart
void handleStatus(UnlockDetectorStatus status) {
  // High-level online/offline checks
  if (status.isOnline) {
    // User is actively using the app
  }
  if (status.isOffline) {
    // User is either in background or device is locked
  }

  // Specific state checks
  if (status.isForeground) {
    // App is visible and active
  }
  if (status.isBackground) {
    // App is in background
  }
  if (status.isLocked) {
    // Device is locked
  }
  if (status.isUnlocked) {
    // Device was just unlocked
  }
}
```

### 4. Clean Up

When you're done with detection, dispose of resources:

```dart
await UnlockDetector.dispose();
```

## Complete Example

Here's a full example showing common usage patterns:

```dart
import 'package:flutter/material.dart';
import 'package:unlock_detector/unlock_detector.dart';

class UserPresenceWidget extends StatefulWidget {
  @override
  State<UserPresenceWidget> createState() => _UserPresenceWidgetState();
}

class _UserPresenceWidgetState extends State<UserPresenceWidget> {
  StreamSubscription? _subscription;
  String _status = 'Unknown';
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _setupDetector();
  }

  Future<void> _setupDetector() async {
    try {
      // Initialize the detector
      await UnlockDetector.initialize();

      // Start listening to status changes
      _subscription = UnlockDetector.stream.listen(
        (status) {
          setState(() {
            _status = status.toString();
            _isOnline = status.isOnline;
          });

          // Update backend about user's status
          if (status.isOnline) {
            print('Updating backend: User is online');
          } else if (status.isOffline) {
            print('Updating backend: User is offline');
          }
        },
        onError: (error) {
          if (error is UnlockDetectorException) {
            print('Detector error: ${error.message}');
          }
        },
      );
    } on UnlockDetectorException catch (e) {
      print('Failed to initialize: ${e.message}');
    }
  }

  @override
  void dispose() {
    // Clean up
    _subscription?.cancel();
    UnlockDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.circle : Icons.circle_outlined,
              color: _isOnline ? Colors.green : Colors.red,
            ),
            Text('Status: $_status'),
            Text('User is ${_isOnline ? 'Online' : 'Offline'}'),
          ],
        ),
      ),
    );
  }
}## Platform-Specific Notes

### Android

- Reliable detection of lock, unlock, and screen-on events
- Works in background while the app process is alive
- Uses system broadcasts for detection

### iOS

- Limited detection using data protection APIs
- Only works when app is active or recently backgrounded
- Returns background/foreground transitions
- Detection may be unreliable in some scenarios

To check platform-specific behavior at runtime:

```dart
print(UnlockDetector.getPlatformInfo());
```

## Error Handling

The plugin provides the `UnlockDetectorException` class for error cases:

```dart
try {
  await UnlockDetector.initialize();
} on UnlockDetectorException catch (e) {
  print('Failed to initialize: ${e.message}');
  if (e.originalError != null) {
    print('Original error: ${e.originalError}');
  }
}
```

## Platform-Specific Notes

### Android

- Full support for all status types
- Reliable background operation
- Accurate lock/unlock detection using system broadcasts
- Works consistently while app process is alive

### iOS

- Full support for foreground/background detection
- Limited lock/unlock detection (works when app is active)
- Background detection may be limited by iOS
- Uses data protection APIs for lock state

Check platform behavior at runtime:

```dart
print(UnlockDetector.getPlatformInfo());
```

## Exception Handling

The plugin provides `UnlockDetectorException` for error cases:

```dart
try {
  await UnlockDetector.initialize();
} on UnlockDetectorException catch (e) {
  print('Detector error: ${e.message}');
  if (e.originalError != null) {
    print('Original error: ${e.originalError}');
  }
}
```

## Support

If you find this plugin helpful, consider supporting the development:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
