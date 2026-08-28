package com.mustafa707.unlock_detector

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * UnlockDetectorPlugin — detects device lock/unlock and screen-on events.
 *
 * App foreground/background detection is handled in Dart via the Flutter app
 * lifecycle, so this plugin covers only the device-level signals.
 */
class UnlockDetectorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var isReceiverRegistered = false

    private val lockStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_USER_PRESENT -> eventSink?.success("UNLOCKED")
                Intent.ACTION_SCREEN_OFF -> eventSink?.success("LOCKED")
                Intent.ACTION_SCREEN_ON -> eventSink?.success("SCREEN_ON")
            }
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "unlock_detector")
        eventChannel = EventChannel(binding.binaryMessenger, "unlock_detector_stream")
        channel.setMethodCallHandler(this)

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerReceiver()
            }

            override fun onCancel(arguments: Any?) {
                unregisterReceiver()
                eventSink = null
            }
        })
    }

    private fun registerReceiver() {
        if (isReceiverRegistered || context == null) return

        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context?.registerReceiver(lockStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context?.registerReceiver(lockStateReceiver, filter)
            }

            isReceiverRegistered = true
        } catch (e: Exception) {
            eventSink?.error("REGISTRATION_ERROR", "Failed to register receiver: ${e.message}", null)
        }
    }

    private fun unregisterReceiver() {
        if (!isReceiverRegistered || context == null) return

        try {
            context?.unregisterReceiver(lockStateReceiver)
        } catch (e: IllegalArgumentException) {
            // Receiver was not registered — ignore.
        }
        isReceiverRegistered = false
    }

    /** Returns whether the keyguard (lock screen) is currently showing. */
    private fun isDeviceLocked(): Boolean {
        val keyguard = context?.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return keyguard?.isKeyguardLocked ?: false
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "detect_on" -> result.success("Detection started")
            "detect_off" -> {
                unregisterReceiver()
                result.success("Detection stopped")
            }
            "is_device_locked" -> result.success(isDeviceLocked())
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterReceiver()
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // setStreamHandler(null) does not invoke onCancel, so the sink would
        // otherwise outlive the engine it belongs to.
        eventSink = null
        context = null
    }
}
