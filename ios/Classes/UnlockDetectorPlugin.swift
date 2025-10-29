import Flutter
import UIKit

public class UnlockDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "unlock_detector", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "unlock_detector_stream", binaryMessenger: registrar.messenger())
        let instance = UnlockDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        // Better lock detection - monitors data protection state
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

        // Also monitor app state changes
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.appWentBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.appWentForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "detect_on" {
            result("Detection started")
        } else {
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

    @objc private func appWentBackground() {
        eventSink?(["event": "BACKGROUND", "type": "app_state"])
    }

    @objc private func appWentForeground() {
        eventSink?(["event": "FOREGROUND", "type": "app_state"])
    }
}