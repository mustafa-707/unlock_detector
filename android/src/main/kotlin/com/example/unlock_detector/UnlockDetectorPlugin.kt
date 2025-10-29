package com.example.unlock_detector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** UnlockDetectorPlugin - Simplified for online/offline detection */
class UnlockDetectorPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var isReceiverRegistered = false
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var lifecycleObserver: LifecycleEventObserver? = null

    private val lockStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_USER_PRESENT -> {
                    // Device unlocked - user authenticated
                    eventSink?.success("UNLOCKED")
                }
                Intent.ACTION_SCREEN_OFF -> {
                    // Screen locked - user definitely offline
                    eventSink?.success("LOCKED")
                }
            }
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "unlock_detector")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "unlock_detector_stream")
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
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context?.registerReceiver(
                    lockStateReceiver, 
                    filter,
                    Context.RECEIVER_NOT_EXPORTED
                )
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
            isReceiverRegistered = false
        } catch (e: IllegalArgumentException) {
            // Receiver was not registered, ignore
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "detect_on" -> {
                result.success("Detection started")
            }
            "detect_off" -> {
                unregisterReceiver()
                result.success("Detection stopped")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterReceiver()
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        context = null
    }

    // ActivityAware - Track only essential lifecycle events
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityPluginBinding = binding
        setupLifecycleObserver(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        removeLifecycleObserver()
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityPluginBinding = binding
        setupLifecycleObserver(binding)
    }

    override fun onDetachedFromActivity() {
        removeLifecycleObserver()
        activityPluginBinding = null
    }

    private fun setupLifecycleObserver(binding: ActivityPluginBinding) {
        val activity = binding.activity
        if (activity is LifecycleOwner) {
            lifecycleObserver = LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_PAUSE -> {
                        // App going to background - user switched away
                        eventSink?.success("BACKGROUND")
                    }
                    Lifecycle.Event.ON_RESUME -> {
                        // App in foreground - user is actively using it
                        eventSink?.success("FOREGROUND")
                    }
                    else -> {
                        // Ignore other lifecycle events
                    }
                }
            }
            activity.lifecycle.addObserver(lifecycleObserver!!)
        }
    }

    private fun removeLifecycleObserver() {
        activityPluginBinding?.activity?.let { activity ->
            if (activity is LifecycleOwner) {
                lifecycleObserver?.let { observer ->
                    activity.lifecycle.removeObserver(observer)
                }
            }
        }
        lifecycleObserver = null
    }
}