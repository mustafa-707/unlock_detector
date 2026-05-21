import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web registrant for the `unlock_detector` plugin.
///
/// Foreground/background and idle detection on the web are handled entirely by
/// the pure-Dart [UnlockDetector] via the Flutter app lifecycle, so this
/// registrant performs no setup.
class UnlockDetectorWeb {
  static void registerWith(Registrar registrar) {}
}
