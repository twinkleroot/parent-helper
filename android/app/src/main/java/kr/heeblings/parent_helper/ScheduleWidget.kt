package kr.heeblings.parent_helper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val title = widgetData.getString("title", "일정 없음")
                val message = widgetData.getString("message", "오늘 남은 일정이 없습니다.")
                val subMessage = widgetData.getString("subMessage", "")

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_message, message)
                setTextViewText(R.id.widget_sub_message, subMessage)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}