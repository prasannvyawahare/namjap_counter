package com.namjap.namjap_counter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
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
 *
 * Colours follow the app's own dark-mode preference rather than the system
 * theme, so the widget matches the app the user actually sees.
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
        val dark = widgetData.getBoolean(KEY_DARK, true)

        for (widgetId in appWidgetIds) {
            // A full update re-inflates the layout, which the launcher shows as
            // a flash. Since a count changes nothing but text and the bar, the
            // first paint of a widget lays it out in full and everything after
            // is merged into the views already on screen — no re-inflation, no
            // flicker. A theme change is the one thing that needs the full pass
            // again, so it is tracked alongside.
            val needsFullPaint = laidOut[widgetId] != dark

            val views = RemoteViews(context.packageName, R.layout.namjap_widget)
            applyProgress(views, count, goal, remaining, percent, streak)
            // Re-applied on every pass, not just the full one. They are three
            // cheap actions, and pinning them to the full paint would mean any
            // disagreement between this map and the host's cache leaves a
            // widget whose buttons quietly do nothing.
            applyActions(context, views, widgetData)

            if (needsFullPaint) {
                applyTheme(context, views, dark)
                appWidgetManager.updateAppWidget(widgetId, views)
                laidOut[widgetId] = dark
            } else {
                appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { laidOut.remove(it) }
    }

    /** The numbers — everything that changes when someone counts. */
    private fun applyProgress(
        views: RemoteViews,
        count: Int,
        goal: Int,
        remaining: Int,
        percent: Int,
        streak: Int,
    ) = views.run {
        setTextViewText(
            R.id.widget_count,
            if (goal > 0) "$count / $goal Chants" else "$count Chants",
        )
        setTextViewText(
            R.id.widget_remaining,
            if (goal > 0) "Remaining: $remaining" else "No daily goal set",
        )
        setTextViewText(R.id.widget_streak, streakLabel(streak))
        setProgressBar(R.id.widget_progress_dark, 100, percent.coerceIn(0, 100), false)
        setProgressBar(R.id.widget_progress_light, 100, percent.coerceIn(0, 100), false)
    }

    /** Backgrounds and text colours, straight out of AppTheme. */
    private fun applyTheme(context: Context, views: RemoteViews, dark: Boolean) {
        fun color(id: Int) = ContextCompat.getColor(context, id)

        val onSurface = color(if (dark) R.color.widget_dark_on_surface else R.color.widget_light_on_surface)
        val onSurfaceMuted =
            color(if (dark) R.color.widget_dark_on_surface_muted else R.color.widget_light_on_surface_muted)
        val primary = color(if (dark) R.color.widget_saffron else R.color.widget_deep_orange)

        views.run {
            setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (dark) R.drawable.widget_background_dark else R.drawable.widget_background_light,
            )
            setTextColor(R.id.widget_title, onSurfaceMuted)
            setTextColor(R.id.widget_count, onSurface)
            setTextColor(R.id.widget_remaining, onSurfaceMuted)
            setTextColor(R.id.widget_streak, onSurface)

            // Only one bar is ever shown; a ProgressBar's drawable cannot be
            // swapped over RemoteViews, so the themed pair lives in the layout.
            setViewVisibility(R.id.widget_progress_dark, if (dark) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.widget_progress_light, if (dark) View.GONE else View.VISIBLE)

            setInt(
                R.id.widget_open,
                "setBackgroundResource",
                if (dark) R.drawable.widget_button_surface_dark else R.drawable.widget_button_surface_light,
            )
            setTextColor(R.id.widget_open, primary)

            setInt(
                R.id.widget_increment,
                "setBackgroundResource",
                if (dark) R.drawable.widget_button_primary_dark else R.drawable.widget_button_primary_light,
            )
            setTextColor(R.id.widget_increment, android.graphics.Color.WHITE)
        }
    }

    /** Where the taps go. */
    private fun applyActions(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
    ) = views.run {
        setOnClickPendingIntent(R.id.widget_increment, incrementIntent(context, widgetData))
        setOnClickPendingIntent(
            R.id.widget_open,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        // Tapping the icon and name opens the app too.
        setOnClickPendingIntent(
            R.id.widget_header,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
    }

    /**
     * Counting from the widget runs Dart in a background worker, and that
     * worker finds its entry point through a raw Dart callback handle stored on
     * disk. The handle does not survive a rebuild of the app: until the app has
     * been opened once and registered afresh, the stored one resolves to
     * nothing and the worker gives up silently — a button that looks alive and
     * does nothing.
     *
     * So the button is only wired to the background path once Dart has
     * confirmed the handle belongs to this build. Before that it opens the app,
     * which registers on the way in and makes the next tap count properly.
     */
    private fun incrementIntent(
        context: Context,
        widgetData: SharedPreferences,
    ): PendingIntent =
        if (widgetData.getBoolean(KEY_CALLBACK_READY, false)) {
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(URI_INCREMENT))
        } else {
            Log.i(TAG, "No Dart callback registered yet; +1 will open the app instead.")
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
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
        const val KEY_DARK = "namjap_dark"
        const val KEY_CALLBACK_READY = "namjap_callback_ready"

        private const val TAG = "NamjapWidget"

        const val URI_INCREMENT = "namjap://increment"
        const val URI_REFRESH = "namjap://refresh"

        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        /**
         * Widget id to the theme it was last fully painted with. Kept in memory
         * rather than on disk on purpose: a new process means a new APK or a
         * cold start, and either way the layout deserves one honest full paint
         * before partial updates start merging into it.
         */
        private val laidOut = mutableMapOf<Int, Boolean>()
    }
}
