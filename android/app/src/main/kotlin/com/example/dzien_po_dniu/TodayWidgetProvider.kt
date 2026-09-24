package com.example.dzien_po_dniu

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        update(context, appWidgetManager, appWidgetId)
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
            val options = manager.getAppWidgetOptions(id)
            val mode = WidgetLayoutMode.fromSize(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110),
            )
            val padding = if (mode == WidgetLayoutMode.SMALL) 8 else 14
            val paddingPx = (padding * context.resources.displayMetrics.density).toInt()
            views.setViewPadding(R.id.widget_today_root, paddingPx, paddingPx, paddingPx, paddingPx)
            val count = preferences.getInt("remainingTaskCount", 0)
            views.setTextViewText(R.id.widget_today_count, "$count pozostałych")
            val titles = mutableListOf<String>()
            val tasks = JSONArray(preferences.getString("tasksJson", "[]"))
            for (index in 0 until tasks.length()) {
                titles.add(tasks.optJSONObject(index)?.optString("title").orEmpty())
            }
            views.setViewVisibility(
                R.id.widget_today_tasks,
                if (mode == WidgetLayoutMode.SMALL) View.GONE else View.VISIBLE,
            )
            views.setInt(R.id.widget_today_tasks, "setMaxLines", if (mode == WidgetLayoutMode.LARGE) 3 else 2)
            views.setTextViewText(
                R.id.widget_today_tasks,
                titles.take(if (mode == WidgetLayoutMode.LARGE) 3 else 2)
                    .joinToString("\n") { "• $it" }
                    .ifBlank { "Brak zadań na dziś" },
            )
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
