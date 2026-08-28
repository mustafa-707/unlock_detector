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

  /// The IOKit main port.
  ///
  /// `kIOMasterPortDefault` was renamed to `kIOMainPortDefault` in macOS 12 and
  /// is deprecated. Both are `MACH_PORT_NULL`, which IOKit reads as "use the
  /// default port", so the fallback spells out the value rather than naming the
  /// deprecated constant and warning on every build.
  private var ioMainPort: mach_port_t {
    if #available(macOS 12.0, *) {
      return kIOMainPortDefault
    }
    return mach_port_t(MACH_PORT_NULL)
  }

  /// Seconds since the last system-wide keyboard or mouse input, read from the
  /// IOKit HID system. Returns 0 if it cannot be determined.
  private func systemIdleSeconds() -> Int {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(
      ioMainPort,
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
          // HIDIdleTime comes back as a CFNumber whose concrete width varies;
          // going through NSNumber avoids a failed bridge to a fixed type.
          let idleNanos = (dict["HIDIdleTime"] as? NSNumber)?.uint64Value else {
      return 0
    }
    return Int(idleNanos / 1_000_000_000)
  }
}
