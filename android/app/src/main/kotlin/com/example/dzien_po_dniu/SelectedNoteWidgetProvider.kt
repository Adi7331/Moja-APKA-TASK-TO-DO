package com.example.dzien_po_dniu

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.widget.RemoteViews

class SelectedNoteWidgetProvider : AppWidgetProvider() {
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
            val component = ComponentName(context, SelectedNoteWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { id -> update(context, manager, id) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val preferences = context.getSharedPreferences(MainActivity.WIDGETS_PREFERENCES, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_selected_note)
            views.setTextViewText(R.id.widget_note_title, preferences.getString("noteTitle", "")?.ifBlank { "Brak wybranej notatki" })
            views.setTextViewText(R.id.widget_note_preview, preferences.getString("notePreview", "")?.ifBlank { "Wybierz notatkę w aplikacji" })
            val pendingIntent = PendingIntent.getActivity(
                context,
                4102,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_note_root, pendingIntent)
            manager.updateAppWidget(id, views)
        }
    }
}
