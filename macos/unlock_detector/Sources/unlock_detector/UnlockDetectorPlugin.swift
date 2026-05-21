import Cocoa
import FlutterMacOS
import IOKit

/// macOS implementation of `unlock_detector`.
///
/// Provides system-wide idle time. Foreground/background (window focus) is
/// handled in Dart via the Flutter app lifecycle.
public class UnlockDetectorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "unlock_detector", binaryMessenger: registrar.messenger)
    let instance = UnlockDetectorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "get_system_idle_seconds":
      result(systemIdleSeconds())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Seconds since the last system-wide keyboard or mouse input, read from the
  /// IOKit HID system. Returns 0 if it cannot be determined.
  private func systemIdleSeconds() -> Int {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(
      kIOMasterPortDefault,
      IOServiceMatching("IOHIDSystem"),
      &iterator
    ) == KERN_SUCCESS else {
      return 0
    }
    defer { IOObjectRelease(iterator) }

    let entry = IOIteratorNext(iterator)
    guard entry != 0 else { return 0 }
    defer { IOObjectRelease(entry) }

    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let dict = properties?.takeRetainedValue() as? [String: Any],
          let idleNanos = dict["HIDIdleTime"] as? Int64 else {
      return 0
    }
    return Int(idleNanos / 1_000_000_000)
  }
}
