# Unlock Detector Plugin for Flutter

[![Pub Package](https://img.shields.io/pub/v/unlock_detector.svg)](https://pub.dev/packages/unlock_detector)

This Flutter plugin allows you to detect screen lock and unlock events on both Android and iOS devices.

## Features

- Detect when the screen is locked or unlocked.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  unlock_detector:
```

Sure, here is a more detailed and explanatory version of the README usage section:

---

## Usage

To get started with the Unlock Detector package, follow these steps:

1. **Initialize the UnlockDetector instance:**

   Create an instance of `UnlockDetector` and initialize it using the `initialize` method. This sets up the detector to start monitoring the lock/unlock status of the device.

   ```dart
    final UnlockDetector _unlockDetector = UnlockDetector();
      ...
    _unlockDetector.initialize(); // Start detection
   ```

2. **Set up a listener for the lock/unlock stream:**

   Use the `stream` property to listen for changes in the lock/unlock status. The stream provides real-time updates whenever the device's lock state changes.

   ```dart
   String _status = 'Unknown'; // Initial status

   _unlockDetector.stream?.listen((event) {
     setState(() {
       _status = event; // Update status with the latest event
     });
   });
   ```

3. **Display the lock/unlock status in your UI:**

   Use the `_status` variable to display the current lock/unlock status in your app's UI. In this example, the status is displayed in the center of the screen.

```dart
 ...
        body: Center(
          child: Text('Lock/Unlock Status: $_status'),
        ),
          ...
```

## Support

If you find this plugin helpful, consider supporting me:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
