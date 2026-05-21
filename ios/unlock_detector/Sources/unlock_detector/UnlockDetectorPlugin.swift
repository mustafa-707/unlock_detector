import Flutter
import UIKit

/// UnlockDetectorPlugin — detects device lock/unlock on iOS.
///
/// App foreground/background detection is handled in Dart via the Flutter app
/// lifecycle, so this plugin covers only the device-level signals.
public class UnlockDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "unlock_detector", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "unlock_detector_stream", binaryMessenger: registrar.messenger())
        let instance = UnlockDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        // Lock detection via data-protection availability.
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.screenLocked),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.screenUnlocked),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detect_on":
            result("Detection started")
        case "detect_off":
            result("Detection stopped")
        case "is_device_locked":
            // Best-effort: data protection is unavailable while the device is locked.
            result(!UIApplication.shared.isProtectedDataAvailable)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    @objc private func screenLocked() {
        eventSink?(["event": "LOCKED", "type": "data_protection"])
    }

    @objc private func screenUnlocked() {
        eventSink?(["event": "UNLOCKED", "type": "data_protection"])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
