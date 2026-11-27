package com.streak.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/** The month calendar widget; drawing lives in [CalendarRenderer]. */
class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_HOME_WIDGET_UPDATE -> CalendarRenderer.updateAll(context)
            CalendarRenderer.ACTION_PREV,
            CalendarRenderer.ACTION_NEXT,
            CalendarRenderer.ACTION_TODAY -> {
                val id = intent.getIntExtra(
                    CalendarRenderer.EXTRA_WIDGET,
                    AppWidgetManager.INVALID_APPWIDGET_ID,
                )
                if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
                val by = when (intent.action) {
                    CalendarRenderer.ACTION_PREV -> -1
                    CalendarRenderer.ACTION_NEXT -> 1
                    else -> 0
                }
                CalendarRenderer.shift(context, id, by)
                CalendarRenderer.update(context, AppWidgetManager.getInstance(context), id)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetRefreshReceiver.keepFresh(context)
        for (id in appWidgetIds) CalendarRenderer.update(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        CalendarRenderer.update(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            CalendarRenderer.forget(context, id)
            WidgetConfig.forget(context, id)
        }
    }

    private companion object {
        const val ACTION_HOME_WIDGET_UPDATE =
            "es.antonborri.home_widget.action.UPDATE_WIDGET"
    }
}
