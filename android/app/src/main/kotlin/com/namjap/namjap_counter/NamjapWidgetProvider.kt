package com.namjap.namjap_counter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Renders today's progress on the home screen.
 *
 * The provider is a pure view: it never counts anything. Numbers come from the
 * key/value store that the Flutter side writes on every change, and the two
 * buttons hand straight back to Dart — `+1` through home_widget's background
 * broadcast, `Open` through the launch intent.
 */
class NamjapWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = DATE_FORMAT.format(Date())
        // The stored numbers describe whichever day Dart last painted. If the
        // clock has since passed midnight and nothing has repainted us yet,
        // today's count is zero by definition — show that rather than yesterday.
        val stale = widgetData.getString(KEY_DATE, null) != today

        val count = if (stale) 0 else widgetData.readInt(KEY_COUNT)
        val goal = widgetData.readInt(KEY_GOAL)
        val remaining = if (stale) goal else widgetData.readInt(KEY_REMAINING)
        val percent = if (stale) 0 else widgetData.readInt(KEY_PERCENT)
        // A streak carries into the new day: it only breaks once a day ends
        // with nothing chanted, which yesterday's value already accounts for.
        val streak = widgetData.readInt(KEY_STREAK)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.namjap_widget).apply {
                setTextViewText(
                    R.id.widget_count,
                    if (goal > 0) "$count / $goal Chants" else "$count Chants",
                )
                setTextViewText(
                    R.id.widget_remaining,
                    if (goal > 0) "Remaining: $remaining" else "No daily goal set",
                )
                setTextViewText(R.id.widget_streak, streakLabel(streak))

                setViewVisibility(R.id.widget_progress, if (goal > 0) android.view.View.VISIBLE else android.view.View.GONE)
                setProgressBar(R.id.widget_progress, 100, percent.coerceIn(0, 100), false)

                setOnClickPendingIntent(
                    R.id.widget_increment,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(URI_INCREMENT)),
                )
                setOnClickPendingIntent(
                    R.id.widget_open,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                // Tapping anywhere else opens the app too.
                setOnClickPendingIntent(
                    R.id.widget_title,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun streakLabel(streak: Int): String = when (streak) {
        0 -> "🔥 No streak yet"
        1 -> "🔥 1 Day Streak"
        else -> "🔥 $streak Day Streak"
    }

    /**
     * home_widget stores a Dart `int` as either an Int or a Long depending on
     * its magnitude, and [SharedPreferences.getInt] throws on the other one.
     */
    private fun SharedPreferences.readInt(key: String): Int = try {
        getInt(key, 0)
    } catch (_: ClassCastException) {
        getLong(key, 0L).toInt()
    }

    companion object {
        // Must match HomeWidgetService in the Dart layer.
        const val KEY_DATE = "namjap_date"
        const val KEY_COUNT = "namjap_count"
        const val KEY_GOAL = "namjap_goal"
        const val KEY_REMAINING = "namjap_remaining"
        const val KEY_STREAK = "namjap_streak"
        const val KEY_PERCENT = "namjap_percent"

        const val URI_INCREMENT = "namjap://increment"
        const val URI_REFRESH = "namjap://refresh"

        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    }
}
