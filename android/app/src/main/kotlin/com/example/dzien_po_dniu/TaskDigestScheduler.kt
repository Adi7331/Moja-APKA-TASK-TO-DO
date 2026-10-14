package com.example.dzien_po_dniu

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

internal object TaskDigestScheduler {
    private const val CONFIG = "task_digest_config"
    private const val ALARM_REQUEST_CODE = 74321
    private const val NOTIFICATION_ID = 74322
    private const val CHANNEL_ID = "task_digest"
    const val ACTION_DIGEST = "com.example.dzien_po_dniu.TASK_DIGEST"

    fun update(context: Context, enabled: Boolean, interval: Int, start: Int, end: Int) {
        context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", enabled)
            .putInt("interval", interval.coerceIn(15, 1440))
            .putInt("start", start.coerceIn(0, 1439))
            .putInt("end", end.coerceIn(0, 1439))
            .apply()
        if (enabled && start != end) scheduleNext(context) else cancel(context)
        if (enabled && start != end) refreshPostedNotification(context)
    }

    fun restore(context: Context) {
        val preferences = context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE)
        if (preferences.getBoolean("enabled", false) && preferences.getInt("start", 540) != preferences.getInt("end", 1260)) {
            scheduleNext(context)
        }
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(alarmIntent(context))
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
    }

    fun scheduleNext(context: Context) {
        val preferences = context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE)
        if (!preferences.getBoolean("enabled", false)) return
        val interval = preferences.getInt("interval", 60).coerceIn(15, 1440)
        val start = preferences.getInt("start", 540).coerceIn(0, 1439)
        val end = preferences.getInt("end", 1260).coerceIn(0, 1439)
        val next = nextDigestOccurrence(
            now = LocalDateTime.now(),
            interval = interval,
            start = start,
            end = end,
        ) ?: return
        val pending = alarmIntent(context)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val time = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, time, pending)
        }
    }

    fun onAlarm(context: Context) {
        try {
            val tasks = currentDueTasks(context)
            if (tasks.isNotEmpty()) showNotification(context, tasks)
        } finally {
            scheduleNext(context)
        }
    }

    internal fun currentDueTasks(context: Context): List<String> {
        val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.local_tasks_v1", null) ?: return emptyList()
        val array = JSONArray(raw)
        val entries = mutableListOf<TaskDigestEntry>()
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val title = item.optString("title", "").trim()
            entries.add(
                TaskDigestEntry(
                    id = item.optString("id", "").ifBlank { "legacy-$index" },
                    title = title.ifBlank { "Bez tytułu" },
                    status = item.optString("status", "todo"),
                    dueAt = parseDueAt(item.optString("dueAt", "")),
                ),
            )
        }
        return tasksForDigest(entries, LocalDateTime.now()).map { it.title }
    }

    private fun refreshPostedNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val tasks = currentDueTasks(context)
        when {
            tasks.isEmpty() -> manager.cancel(NOTIFICATION_ID)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                manager.activeNotifications.any { it.id == NOTIFICATION_ID } ->
                showNotification(context, tasks)
        }
    }

    private fun parseDueAt(value: String): LocalDateTime? {
        if (value.isBlank() || value == "null") return null
        return try {
            LocalDateTime.parse(value)
        } catch (_: Exception) {
            try {
                OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.systemDefault()).toLocalDateTime()
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun showNotification(context: Context, titles: List<String>): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Przypomnienia o zadaniach", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("open_today", true)
        val contentIntent = PendingIntent.getActivity(
            context, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0,
        )
        val count = titles.size
        val noun = taskNoun(count)
        val visibleTitles = titles.take(3)
        val remaining = count - visibleTitles.size
        val body = buildList {
            addAll(visibleTitles)
            if (remaining > 0) add("+ $remaining ${remainingTaskNoun(remaining)}")
        }.joinToString("\n")
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Masz $count $noun do zrobienia")
            .setContentText(titles.first())
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
            return true
        } catch (_: SecurityException) {
            // Notification permission can be revoked after the setting is enabled.
            return false
        }
    }

    private fun taskNoun(count: Int): String = when {
        count == 1 -> "zadanie"
        count % 10 in 2..4 && count % 100 !in 12..14 -> "zadania"
        else -> "zadań"
    }

    private fun remainingTaskNoun(count: Int): String = when {
        count == 1 -> "kolejne zadanie"
        count % 10 in 2..4 && count % 100 !in 12..14 -> "kolejne zadania"
        else -> "kolejnych zadań"
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        ALARM_REQUEST_CODE,
        Intent(context, TaskDigestAlarmReceiver::class.java).setAction(ACTION_DIGEST),
        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0,
    )
}

class TaskDigestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == TaskDigestScheduler.ACTION_DIGEST) TaskDigestScheduler.onAlarm(context)
    }
}

class TaskDigestBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                TaskDigestScheduler.restore(context)
                DailyPlanScheduler.restore(context)
            }
        }
    }
}
