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

## Usage

```dart
  final UnlockDetector _unlockDetector = UnlockDetector();
  String _status = 'Unknown';

    _unlockDetector.startDetection();
    _unlockDetector.lockUnlockStream?.listen((event) {
      setState(() {
        _status = event;
      });
    });

    ...
        body: Center(
          child: Text('Lock/Unlock Status: $_status'),
        ),
           ...

```

## Support

If you find this plugin helpful, consider supporting me:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-1.svg)](https://buymeacoffee.com/is10vmust)
