package com.example.dzien_po_dniu

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id -> update(context, appWidgetManager, id) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { id -> update(context, manager, id) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val preferences = context.getSharedPreferences(MainActivity.WIDGETS_PREFERENCES, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            val count = preferences.getInt("remainingTaskCount", 0)
            views.setTextViewText(R.id.widget_today_count, "$count pozostałych")
            val titles = mutableListOf<String>()
            val tasks = JSONArray(preferences.getString("tasksJson", "[]"))
            for (index in 0 until tasks.length()) {
                titles.add(tasks.optJSONObject(index)?.optString("title").orEmpty())
            }
            views.setTextViewText(R.id.widget_today_tasks, titles.joinToString("\n") { "• $it" }.ifBlank { "Brak zadań na dziś" })
            val pendingIntent = PendingIntent.getActivity(
                context,
                4101,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_today_root, pendingIntent)
            manager.updateAppWidget(id, views)
        }
    }
}
