package com.soundclone.soundcloud_clone

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "biobeats/local_notifications"
    private val notificationChannelId = "biobeats_notifications"
    private val permissionRequestCode = 4242
    private var notificationChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        notificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    createNotificationChannel()
                    // Respond first so Dart unblocks and registers setMethodCallHandler
                    // before the notificationTap event is delivered. If we called
                    // invokeMethod here (before result.success), Dart would still be
                    // awaiting the "initialize" response and the handler would not yet
                    // be registered — the tap event would be silently dropped.
                    result.success(null)
                    deliverInitialNotificationTap()
                }

                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }

                "showNotification" -> {
                    createNotificationChannel()
                    val title = call.argument<String>("title") ?: "BioBeats"
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload")
                    showNotification(title, body, payload)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Called when a notification is tapped while the app is already running
    // (foreground or background). FLAG_ACTIVITY_SINGLE_TOP ensures Android
    // calls onNewIntent instead of onCreate in this case.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intent.getStringExtra("biobeats_notification_payload") ?: return
        intent.removeExtra("biobeats_notification_payload")
        // Post to the next looper iteration so that Flutter engine state
        // transitions triggered by super.onNewIntent() (plugin dispatch, deep-link
        // processing) fully settle before the tap event is sent. Sending
        // synchronously inside the onNewIntent stack frame can cause the
        // MethodChannel message to be silently dropped on some Android versions.
        mainHandler.post {
            notificationChannel?.invokeMethod("notificationTap", payload)
        }
    }

    // Delivers the startup notification tap for the killed-app cold-start case.
    // Called after result.success(null) is sent for "initialize", so the Dart
    // setMethodCallHandler is guaranteed to be registered by the time the
    // notificationTap event arrives.
    private fun deliverInitialNotificationTap() {
        val payload = intent?.getStringExtra("biobeats_notification_payload") ?: return
        intent.removeExtra("biobeats_notification_payload")
        mainHandler.post {
            notificationChannel?.invokeMethod("notificationTap", payload)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            notificationChannelId,
            "BioBeats notifications",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Realtime BioBeats notifications"
            enableVibration(true)
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            permissionRequestCode
        )
    }

    private fun showNotification(title: String, body: String, payload: String?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        // Use a unique ID per notification so each gets its own PendingIntent.
        // With requestCode=0 and FLAG_UPDATE_CURRENT, every new notification
        // would overwrite the PendingIntent extras of all previous ones —
        // tapping an older notification would deliver the newest payload instead.
        val notificationId = System.currentTimeMillis().toInt()

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("biobeats_notification_payload", payload)
        }
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            pendingIntentFlags
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, notificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }
}
