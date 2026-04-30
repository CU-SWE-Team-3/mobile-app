package com.soundclone.soundcloud_clone

import android.Manifest
<<<<<<< HEAD
=======
import android.app.ActivityManager
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
<<<<<<< HEAD
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.util.Locale

class BioBeatsFirebaseMessagingService : FirebaseMessagingService() {
=======
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONArray
import org.json.JSONObject

class BioBeatsFirebaseMessagingService : FlutterFirebaseMessagingService() {
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
    private val notificationChannelId = "biobeats_notifications"

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
<<<<<<< HEAD
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
=======
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
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
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
<<<<<<< HEAD
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
=======
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
<<<<<<< HEAD
        val pendingIntent = PendingIntent.getActivity(
            this,
            payload.hashCode(),
            launchIntent,
            flags
=======
        val notificationId = idSeed.hashCode()
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            pendingIntentFlags,
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
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
<<<<<<< HEAD
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
=======
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
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
        for (key in listOf("conversationId", "targetConversationId", "chatId", "conversation")) {
            val value = idValue(data[key])
            if (value.isNotEmpty()) return value
        }
<<<<<<< HEAD
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
=======

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
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
    }

    private fun looksLikeObjectId(value: String): Boolean {
        return Regex("^[a-fA-F0-9]{24}$").matches(value)
    }
<<<<<<< HEAD
=======

    private fun isAppInForeground(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val processes = manager.runningAppProcesses ?: return false
        return processes.any {
            it.processName == packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }
>>>>>>> e40c171d5ea8493aa35896758b61804331fa2ca3
}
