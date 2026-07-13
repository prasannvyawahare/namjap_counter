package com.namjap.namjap_counter

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasPolicyAccess())
                    "openPolicySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        result.success(setDnd(enabled))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun hasPolicyAccess(): Boolean =
        notificationManager().isNotificationPolicyAccessGranted

    /// Applies the interruption filter. Uses ALARMS (silence calls and
    /// notifications but still let alarms through) rather than NONE so a session
    /// can't cause the user to sleep through an alarm. Returns false if we lack
    /// policy access — the caller then routes the user to system settings.
    private fun setDnd(enabled: Boolean): Boolean {
        val nm = notificationManager()
        if (!nm.isNotificationPolicyAccessGranted) return false
        nm.setInterruptionFilter(
            if (enabled) NotificationManager.INTERRUPTION_FILTER_ALARMS
            else NotificationManager.INTERRUPTION_FILTER_ALL
        )
        return true
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Only intercept while Dart is actively listening; otherwise let the
        // system handle the volume keys normally.
        val sink = eventSink
        if (sink != null && event?.repeatCount == 0) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    sink.success("up")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    sink.success("down")
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        // Swallow the matching key-up so the OS volume slider never appears.
        if (eventSink != null &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    companion object {
        private const val VOLUME_CHANNEL = "namjap/volume_buttons"
        private const val DND_CHANNEL = "namjap/dnd"
    }
}
