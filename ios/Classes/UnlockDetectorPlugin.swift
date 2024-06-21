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

        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.screenLocked),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.screenUnlocked),
            name: UIScreen.didConnectNotification,
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
        eventSink?("LOCKED")
    }

    @objc private func screenUnlocked() {
        eventSink?("UNLOCKED")
    }
}