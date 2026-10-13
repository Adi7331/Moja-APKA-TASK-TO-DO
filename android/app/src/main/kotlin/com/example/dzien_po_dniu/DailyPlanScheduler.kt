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
import java.time.LocalDateTime
import java.time.ZoneId

/** Reads the current local task cache when the alarm fires, not when it is set. */
internal object DailyPlanScheduler {
    private const val CONFIG = "daily_plan_config"
    private const val REQUEST_CODE = 76311
    private const val NOTIFICATION_ID = 76312
    private const val CHANNEL_ID = "daily_plan"
    const val ACTION = "com.example.dzien_po_dniu.DAILY_PLAN"

    fun update(context: Context, enabled: Boolean, hour: Int, minute: Int) {
        context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", enabled)
            .putInt("hour", hour.coerceIn(0, 23))
            .putInt("minute", minute.coerceIn(0, 59))
            .apply()
        if (enabled) scheduleNext(context) else cancel(context)
    }

    fun restore(context: Context) {
        if (context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE)
                .getBoolean("enabled", false)) scheduleNext(context)
    }

    fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarmIntent(context))
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
    }

    private fun scheduleNext(context: Context) {
        val settings = context.getSharedPreferences(CONFIG, Context.MODE_PRIVATE)
        if (!settings.getBoolean("enabled", false)) return
        val now = LocalDateTime.now()
        var next = now.toLocalDate().atTime(
            settings.getInt("hour", 9).coerceIn(0, 23),
            settings.getInt("minute", 0).coerceIn(0, 59),
        )
        if (!next.isAfter(now)) next = next.plusDays(1)
        val timestamp = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, alarmIntent(context))
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, timestamp, alarmIntent(context))
        }
    }

    fun onAlarm(context: Context) {
        try {
            val count = TaskDigestScheduler.currentDueTasks(context).size
            if (count == 0) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel(
                    CHANNEL_ID, "Plan dnia", NotificationManager.IMPORTANCE_DEFAULT,
                ))
            }
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra("open_today", true)
            val contentIntent = PendingIntent.getActivity(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0,
            )
            val body = if (count == 1) "Masz 1 niewykonane zadanie."
                else "Masz $count niewykonanych zadań."
            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Notification.Builder(context, CHANNEL_ID) else {
                    @Suppress("DEPRECATION") Notification.Builder(context)
                }
            notification.setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Plan na dziś")
                .setContentText(body)
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
            try {
                manager.notify(NOTIFICATION_ID, notification.build())
            } catch (_: SecurityException) {
                // Permission may have been removed after enabling reminders.
            }
        } finally {
            scheduleNext(context)
        }
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, REQUEST_CODE,
        Intent(context, DailyPlanAlarmReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0,
    )
}

class DailyPlanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == DailyPlanScheduler.ACTION) DailyPlanScheduler.onAlarm(context)
    }
}
