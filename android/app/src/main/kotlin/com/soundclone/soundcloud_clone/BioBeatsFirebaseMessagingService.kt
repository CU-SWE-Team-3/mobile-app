package com.soundclone.soundcloud_clone

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONArray
import org.json.JSONObject

class BioBeatsFirebaseMessagingService : FlutterFirebaseMessagingService() {
    private val notificationChannelId = "biobeats_notifications"

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        if (isAppInForeground()) return

        val data = message.data
        val type = data["type"] ?: data["notificationType"] ?: ""
        if (!type.equals("MESSAGE", ignoreCase = true)) return

        val conversationId = conversationIdFrom(data)
        if (conversationId.isEmpty()) return

        createNotificationChannel()
        showMessageNotification(
            title = messageTitle(data, message.notification?.title),
            body = messageBody(data, message.notification?.body),
            payload = "/messages/chat/$conversationId",
            idSeed = data["_id"] ?: data["id"] ?: data["messageId"] ?: conversationId,
        )
    }

    private fun showMessageNotification(
        title: String,
        body: String,
        payload: String,
        idSeed: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

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
        val notificationId = idSeed.hashCode()
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            pendingIntentFlags,
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            notificationChannelId,
            "BioBeats notifications",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Realtime BioBeats notifications"
            enableVibration(true)
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun messageTitle(data: Map<String, String>, fallbackTitle: String?): String {
        val senderName = firstNonIdValue(
            data,
            "senderDisplayName",
            "senderName",
            "actorName",
            "displayName",
        ).ifEmpty { senderNameFromJson(data["senderId"] ?: data["sender"]) }
            .ifEmpty { actorNameFromJson(data["actors"]) }

        if (senderName.isNotEmpty()) return "Message from $senderName"

        val title = fallbackTitle?.trim().orEmpty()
        if (title.isNotEmpty() && !looksLikeObjectId(title)) return title

        return "New message"
    }

    private fun messageBody(data: Map<String, String>, fallbackBody: String?): String {
        val body = firstNonIdValue(
            data,
            "contentSnippet",
            "content",
            "message",
            "text",
            "body",
        )
        if (body.isNotEmpty()) return body

        val fallback = fallbackBody?.trim().orEmpty()
        if (fallback.isNotEmpty() && !looksLikeObjectId(fallback)) return fallback

        return "Tap to open chat"
    }

    private fun conversationIdFrom(data: Map<String, String>): String {
        for (key in listOf("conversationId", "targetConversationId", "chatId", "conversation")) {
            val value = idValue(data[key])
            if (value.isNotEmpty()) return value
        }

        val target = data["target"] ?: data["targetJson"]
        if (!target.isNullOrBlank()) {
            val value = conversationIdFromJson(target)
            if (value.isNotEmpty()) return value
        }

        return idValue(data["targetId"])
    }

    private fun conversationIdFromJson(json: String): String {
        return runCatching {
            val obj = JSONObject(json)
            idValue(obj.opt("conversationId"))
                .ifEmpty { idValue(obj.opt("conversation")) }
                .ifEmpty { idValue(obj.opt("chatId")) }
                .ifEmpty { idValue(obj) }
        }.getOrDefault("")
    }

    private fun senderNameFromJson(json: String?): String {
        if (json.isNullOrBlank()) return ""
        return runCatching {
            val obj = JSONObject(json)
            obj.optString("displayName").trim().takeUnless { looksLikeObjectId(it) }.orEmpty()
        }.getOrDefault("")
    }

    private fun actorNameFromJson(json: String?): String {
        if (json.isNullOrBlank()) return ""
        return runCatching {
            val actors = JSONArray(json)
            if (actors.length() == 0) return@runCatching ""
            actors.optJSONObject(0)
                ?.optString("displayName")
                ?.trim()
                ?.takeUnless { looksLikeObjectId(it) }
                .orEmpty()
        }.getOrDefault("")
    }

    private fun firstNonIdValue(data: Map<String, String>, vararg keys: String): String {
        for (key in keys) {
            val value = data[key]?.trim().orEmpty()
            if (value.isNotEmpty() && !looksLikeObjectId(value)) return value
        }
        return ""
    }

    private fun idValue(value: Any?): String {
        if (value == null) return ""
        if (value is JSONObject) {
            return value.optString("_id").ifEmpty { value.optString("id") }.trim()
        }

        val text = value.toString().trim()
        if (text.isEmpty()) return ""

        return runCatching {
            val obj = JSONObject(text)
            obj.optString("_id").ifEmpty { obj.optString("id") }.trim()
        }.getOrDefault(text)
    }

    private fun looksLikeObjectId(value: String): Boolean {
        return Regex("^[a-fA-F0-9]{24}$").matches(value)
    }

    private fun isAppInForeground(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val processes = manager.runningAppProcesses ?: return false
        return processes.any {
            it.processName == packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }
}
