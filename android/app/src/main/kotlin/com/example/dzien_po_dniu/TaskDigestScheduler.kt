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
import java.time.LocalDate
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
    }

    fun scheduleNext(context: Context) {
        val preferences = context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE)
        if (!preferences.getBoolean("enabled", false)) return
        val interval = preferences.getInt("interval", 60).coerceIn(15, 1440)
        val start = preferences.getInt("start", 540).coerceIn(0, 1439)
        val end = preferences.getInt("end", 1260).coerceIn(0, 1439)
        val next = nextOccurrence(LocalDateTime.now(), interval, start, end) ?: return
        val pending = alarmIntent(context)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val time = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, time, pending)
        }
    }

    private fun nextOccurrence(now: LocalDateTime, interval: Int, start: Int, end: Int): LocalDateTime? {
        if (start == end || interval !in 15..1440) return null
        val nowMinute = now.hour * 60 + now.minute
        val firstOffset = if (end < start && nowMinute < end) -1 else 0
        for (offset in firstOffset..32) {
            val date = now.toLocalDate().plusDays(offset.toLong())
            val begin = date.atStartOfDay().plusMinutes(start.toLong())
            val endDate = if (end < start) date.plusDays(1) else date
            val stop = endDate.atStartOfDay().plusMinutes(end.toLong())
            var candidate = begin
            while (candidate.isBefore(stop)) {
                if (candidate.isAfter(now)) return candidate
                candidate = candidate.plusMinutes(interval.toLong())
            }
        }
        return null
    }

    fun onAlarm(context: Context) {
        try {
            val tasks = currentDueTasks(context)
            if (tasks.isNotEmpty()) showNotification(context, tasks)
        } finally {
            scheduleNext(context)
        }
    }

    private fun currentDueTasks(context: Context): List<String> {
        val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.local_tasks_v1", null) ?: return emptyList()
        val tomorrow = LocalDate.now().plusDays(1).atStartOfDay()
        val array = JSONArray(raw)
        val selected = mutableListOf<Pair<LocalDateTime, String>>()
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("status", "todo") == "done") continue
            val due = parseDueAt(item.optString("dueAt", "")) ?: continue
            if (due.isBefore(tomorrow)) {
                val title = item.optString("title", "").trim()
                if (title.isNotEmpty()) selected.add(due to title)
            }
        }
        return selected.sortedBy { it.first }.map { it.second }
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

    private fun showNotification(context: Context, titles: List<String>) {
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
        val noun = when {
            count == 1 -> "zadanie"
            count in 2..4 -> "zadania"
            else -> "zadań"
        }
        val body = titles.take(3).joinToString("\n") + if (count > 3) "\n…" else ""
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
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notification permission can be revoked after the setting is enabled.
        }
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
            Intent.ACTION_TIMEZONE_CHANGED -> TaskDigestScheduler.restore(context)
        }
    }
}
