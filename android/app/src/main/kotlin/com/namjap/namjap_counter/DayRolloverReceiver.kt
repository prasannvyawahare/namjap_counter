package com.namjap.namjap_counter

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Nudges both out-of-app surfaces onto the new day.
 *
 * The ongoing notification already clears itself at midnight (it is posted with
 * a timeout that expires exactly then), and the widget renders zeros as soon as
 * it notices its stored date is stale. This receiver closes the last gap: it
 * repaints the widget immediately, and wakes the Dart background isolate so a
 * fresh notification is posted for the new day without waiting for the user to
 * open the app.
 *
 * It also runs after a reboot or an update, when widgets come back blank.
 */
class DayRolloverReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // The app's Dart callback handles are rebuilt with the app, so the
            // one the widget's +1 button relies on is now stale. Mark it so the
            // button opens the app instead of firing into nothing, until Dart
            // registers again on the next launch.
            HomeWidgetPlugin.getData(context)
                .edit()
                .putBoolean(NamjapWidgetProvider.KEY_CALLBACK_READY, false)
                .apply()
        }

        redrawWidgets(context)

        // Rebuilding the notification needs the repository, which only Dart
        // can read — so hand off rather than duplicate any of it here.
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse(NamjapWidgetProvider.URI_REFRESH))
                .send()
        } catch (e: Exception) {
            Log.w(TAG, "Could not request a Dart refresh: ${e.message}")
        }
    }

    private fun redrawWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        val ids = manager.getAppWidgetIds(
            ComponentName(context, NamjapWidgetProvider::class.java)
        )
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, NamjapWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
        )
    }

    private companion object {
        const val TAG = "DayRolloverReceiver"
    }
}
