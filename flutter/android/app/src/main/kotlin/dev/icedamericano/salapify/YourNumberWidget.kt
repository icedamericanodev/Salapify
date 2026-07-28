package dev.icedamericano.salapify

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The "Your Number" home screen tile.
 *
 * This class makes NO decisions. It does no money math, no date math, and no
 * formatting. Dart computed every string in money/widget_tile.dart, where all
 * eight states are unit tested, and this only puts them into TextViews. That
 * split is deliberate: nothing here can be covered by `flutter test`, so
 * nothing here is allowed to be interesting.
 *
 * Every value is read as a String. home_widget stores each Dart type in a
 * different slot, so a key whose type ever changed between two builds would
 * make getString throw and blank the tile on a phone nobody can debug.
 *
 * Every read has a fallback equal to the "Start here" state, so a missing or
 * half written preferences file renders like a fresh app rather than a blank
 * box.
 */
class YourNumberWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_your_number)

            val headline = widgetData.getString("yn_headline", null) ?: "Start here"
            val sub = widgetData.getString("yn_sub", null)
                ?: "Add your cash and log one expense. Your daily number appears here."
            val asOf = widgetData.getString("yn_asof", null) ?: ""
            val bar = widgetData.getString("yn_bar", null) ?: "Log an expense"
            val barTap = widgetData.getString("yn_bar_tap", null) ?: "1"
            val sp = widgetData.getString("yn_headline_sp", null)?.toFloatOrNull() ?: 20f

            views.setTextViewText(R.id.yn_headline, headline)
            views.setTextViewTextSize(R.id.yn_headline, TypedValue.COMPLEX_UNIT_SP, sp)
            views.setTextViewText(R.id.yn_sub, sub)
            views.setTextViewText(R.id.yn_bar_label, bar)

            // The "as of" line is the tile's honesty mechanism: Dart bakes the
            // DAY into it, so a stale tile names the day it froze rather than
            // looking current. Hidden only when there is no number to age.
            views.setTextViewText(R.id.yn_asof, asOf)
            views.setViewVisibility(
                R.id.yn_asof,
                if (asOf.isEmpty()) View.GONE else View.VISIBLE,
            )

            tint(views, widgetData, "yn_text", 0xFFFBF3E9.toInt(), R.id.yn_headline)
            tint(views, widgetData, "yn_muted", 0xFFA99182.toInt(), R.id.yn_kicker, R.id.yn_sub, R.id.yn_asof)
            tint(views, widgetData, "yn_accent", 0xFFFF8A3D.toInt(), R.id.yn_bar_label, R.id.yn_bar_plus)

            // Two PendingIntents that differ by DATA URI, not by extras. They
            // share a request code, and Intent.filterEquals ignores extras, so
            // two intents differing only by extras would silently collapse
            // into one and both taps would do the same thing.
            val home = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("salapify://home"),
            )
            val log = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("salapify://log"),
            )
            views.setOnClickPendingIntent(R.id.yn_root, home)
            // A tap is never dead: when logging is not offered the bar opens
            // the app instead of doing nothing.
            views.setOnClickPendingIntent(R.id.yn_bar, if (barTap == "1") log else home)

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /**
     * Applies a stored #AARRGGBB colour, falling back to the Barako dark value
     * when it is missing or malformed. A bad colour can never blank the tile.
     */
    private fun tint(
        views: RemoteViews,
        data: SharedPreferences,
        key: String,
        fallback: Int,
        vararg ids: Int,
    ) {
        val color = try {
            data.getString(key, null)?.let { Color.parseColor(it) } ?: fallback
        } catch (_: IllegalArgumentException) {
            fallback
        }
        ids.forEach { views.setTextColor(it, color) }
    }
}
