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
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.util.Locale

class BioBeatsFirebaseMessagingService : FirebaseMessagingService() {
    private val notificationChannelId = "biobeats_notifications"

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        createNotificationChannel()

        val data = message.data
        val type = (data["type"] ?: data["notificationType"] ?: "").uppercase(Locale.US)
        val isMessage = type == "MESSAGE"
        val title = if (isMessage) {
            "Message from ${senderName(data)}"
        } else {
            safeText(
                data["title"] ?: data["notificationTitle"] ?: message.notification?.title,
                "BioBeats notification"
            )
        }
        val body = if (isMessage) {
            messageBody(data, message.notification?.body)
        } else {
            genericBody(data, message.notification?.body)
        }
        val payload = if (isMessage) {
            val conversationId = conversationId(data)
            if (conversationId.isNotEmpty()) "/messages/chat/$conversationId" else "/messages"
        } else {
            safePayload(data["actionLink"])
        }

        showNotification(title, body, payload)
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

    private fun showNotification(title: String, body: String, payload: String) {
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
        val pendingIntent = PendingIntent.getActivity(
            this,
            payload.hashCode(),
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
        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun senderName(data: Map<String, String>): String {
        for (key in listOf("senderName", "senderDisplayName", "displayName")) {
            val value = data[key]?.trim()
            if (!value.isNullOrEmpty() && !looksLikeObjectId(value)) return value
        }
        for (key in listOf("sender", "senderId", "from", "user", "actor")) {
            val parsed = parseJsonObject(data[key]) ?: continue
            for (nameKey in listOf("displayName", "username", "name")) {
                val value = parsed.optString(nameKey).trim()
                if (value.isNotEmpty() && !looksLikeObjectId(value)) return value
            }
        }
        return "Someone"
    }

    private fun messageBody(data: Map<String, String>, notificationBody: String?): String {
        for (key in listOf("contentSnippet", "content", "messageText", "text")) {
            val value = data[key]?.trim()
            if (!value.isNullOrEmpty() && !looksLikeObjectId(value)) return value
        }
        return safeText(notificationBody, "Tap to open chat")
    }

    private fun genericBody(data: Map<String, String>, notificationBody: String?): String {
        for (key in listOf("body", "contentSnippet", "content", "message", "targetTitle")) {
            val value = data[key]?.trim()
            if (!value.isNullOrEmpty() && !looksLikeObjectId(value)) return value
        }
        return safeText(notificationBody, "Tap to open BioBeats")
    }

    private fun conversationId(data: Map<String, String>): String {
        for (key in listOf("conversationId", "targetConversationId", "chatId", "conversation")) {
            val value = idValue(data[key])
            if (value.isNotEmpty()) return value
        }
        for (key in listOf("target", "targetJson")) {
            val parsed = parseJsonObject(data[key]) ?: continue
            for (idKey in listOf("conversationId", "conversation", "chatId", "_id", "id")) {
                val value = idValue(parsed.opt(idKey))
                if (value.isNotEmpty()) return value
            }
        }
        return idValue(data["targetId"])
    }

    private fun idValue(value: Any?): String {
        if (value == null) return ""
        if (value is JSONObject) {
            return value.optString("_id").ifEmpty { value.optString("id") }
        }
        val text = value.toString().trim()
        if (text.isEmpty()) return ""
        val parsed = parseJsonObject(text)
        if (parsed != null) {
            return parsed.optString("_id").ifEmpty { parsed.optString("id") }
        }
        return text
    }

    private fun safeText(value: String?, fallback: String): String {
        val text = value?.trim()
        if (text.isNullOrEmpty() || looksLikeObjectId(text)) return fallback
        return text
    }

    private fun safePayload(value: String?): String {
        val path = value?.trim()
        if (path.isNullOrEmpty()) return "/notifications"
        return if (path.startsWith("/")) path else "/notifications"
    }

    private fun parseJsonObject(value: String?): JSONObject? {
        val text = value?.trim()
        if (text.isNullOrEmpty() || !text.startsWith("{")) return null
        return try {
            JSONObject(text)
        } catch (_: Exception) {
            null
        }
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
