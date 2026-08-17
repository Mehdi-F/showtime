package com.example.showtime

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LibraryStatsWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.library_stats_widget).apply {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            setTextViewText(R.id.widget_series_line, widgetData.getString("seriesLine", null) ?: "—")
            setTextViewText(R.id.widget_movies_line, widgetData.getString("moviesLine", null) ?: "—")
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
