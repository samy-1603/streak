package com.streak.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.widget.RemoteViews
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import org.json.JSONObject

/**
 * The month calendar widget: each day lists its tasks as coloured labels
 * (from "calendar_data", written by the app's CalendarWidgetService).
 * The arrows page through months, the calendar button comes back to the
 * current month, + adds a task, and a tap on a day opens it in the app.
 */
object CalendarRenderer {

    const val ACTION_PREV = "com.streak.app.CALENDAR_PREV"
    const val ACTION_NEXT = "com.streak.app.CALENDAR_NEXT"
    const val ACTION_TODAY = "com.streak.app.CALENDAR_TODAY"
    const val EXTRA_WIDGET = "calendarWidgetId"

    private const val DATA_PREFS = "HomeWidgetPreferences"
    private const val DATA_KEY = "calendar_data"
    private const val STATE_PREFS = "CalendarWidget"

    private const val RADIUS_DP = 22f
    private const val HEADER_DP = 40f
    private const val WEEKDAYS_DP = 18f
    private const val PAD_DP = 6f
    private const val NUMBER_DP = 20f
    private const val CHIP_DP = 14f
    private const val CHIP_GAP_DP = 2f
    private const val MAX_PX = 1600

    /** Today's ring, matching the app's default accent. */
    private const val ACCENT = 0xFF4F7DF3.toInt()

    private class Chip(val title: String, val color: Int, val done: Boolean)

    private class Day(val count: Int, val chips: List<Chip>)

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
        for (id in ids) update(context, manager, id)
    }

    fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        try {
            manager.updateAppWidget(appWidgetId, build(context, manager, appWidgetId))
        } catch (e: Exception) {
            return
        }
    }

    /** Pages the widget by [months], or back to the current month with 0. */
    fun shift(context: Context, appWidgetId: Int, months: Int) {
        val prefs = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val next = if (months == 0) 0 else prefs.getInt(offsetKey(appWidgetId), 0) + months
        prefs.edit().putInt(offsetKey(appWidgetId), next.coerceIn(-24, 24)).apply()
    }

    fun forget(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .edit().remove(offsetKey(appWidgetId)).apply()
    }

    private fun offsetKey(id: Int) = "offset_$id"

    private fun today(context: Context): LocalDate =
        LocalDateTime.now().minusHours(WidgetPayload.dayCutoff(context).toLong()).toLocalDate()

    private fun build(context: Context, manager: AppWidgetManager, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar)
        val style = CardStyle.loadFor(context, appWidgetId)
        val density = context.resources.displayMetrics.density
        val options = manager.getAppWidgetOptions(appWidgetId)
        val widthDp = sizeOf(options, AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320f)
        val heightDp = sizeOf(options, AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 320f)

        val root = load(context)
        val weekStart = DayOfWeek.of(root?.optInt("weekStart", 1)?.coerceIn(1, 7) ?: 1)
        val days = parseDays(root)
        val today = today(context)
        val offset = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .getInt(offsetKey(appWidgetId), 0)
        val month = YearMonth.from(today).plusMonths(offset.toLong())
        val first = month.atDay(1).with(TemporalAdjusters.previousOrSame(weekStart))
        val rows = ceil((ChronoUnit.DAYS.between(first, month.atEndOfMonth()) + 1) / 7.0)
            .toInt().coerceIn(4, 6)

        views.setImageViewBitmap(
            R.id.calendar_bg,
            CardBitmaps.background(
                (widthDp * density).toInt(),
                (heightDp * density).toInt(),
                RADIUS_DP * density,
                style,
            ),
        )

        // Header: month name (with the year when it is not this year).
        val locale = Locale.getDefault()
        val name = month.format(DateTimeFormatter.ofPattern("LLLL", locale))
            .replaceFirstChar { it.titlecase(locale) }
        views.setTextViewText(
            R.id.calendar_title,
            if (month.year == today.year) name else "$name ${month.year}",
        )
        views.setTextColor(R.id.calendar_title, style.content)
        for (icon in intArrayOf(R.id.calendar_today, R.id.calendar_prev, R.id.calendar_next, R.id.calendar_add)) {
            views.setInt(icon, "setColorFilter", style.content)
        }
        views.setOnClickPendingIntent(R.id.calendar_prev, shiftIntent(context, appWidgetId, ACTION_PREV))
        views.setOnClickPendingIntent(R.id.calendar_next, shiftIntent(context, appWidgetId, ACTION_NEXT))
        views.setOnClickPendingIntent(R.id.calendar_today, shiftIntent(context, appWidgetId, ACTION_TODAY))
        views.setOnClickPendingIntent(R.id.calendar_title, openPage(context, appWidgetId, 100, "calendar:${key(today)}"))
        val addOn = if (offset == 0) today else month.atDay(1)
        views.setOnClickPendingIntent(R.id.calendar_add, openPage(context, appWidgetId, 101, "calendarAdd:${key(addOn)}"))

        val innerWidthDp = widthDp - PAD_DP * 2
        val gridHeightDp = heightDp - PAD_DP * 2 - HEADER_DP - WEEKDAYS_DP
        views.setImageViewBitmap(
            R.id.calendar_weekdays,
            weekdays(weekStart, locale, innerWidthDp, density, style),
        )
        views.setImageViewBitmap(
            R.id.calendar_grid,
            grid(first, month, rows, today, days, innerWidthDp, gridHeightDp, density, style),
        )

        // A transparent tap target over each day.
        views.removeAllViews(R.id.calendar_taps)
        for (row in 0 until rows) {
            val line = RemoteViews(context.packageName, R.layout.widget_calendar_row)
            for (col in 0 until 7) {
                val index = row * 7 + col
                val date = first.plusDays(index.toLong())
                val cell = RemoteViews(context.packageName, R.layout.widget_calendar_cell)
                cell.setOnClickPendingIntent(
                    R.id.calendar_cell,
                    openPage(context, appWidgetId, index, "calendar:${key(date)}"),
                )
                line.addView(R.id.calendar_row, cell)
            }
            views.addView(R.id.calendar_taps, line)
        }
        return views
    }

    private fun weekdays(
        weekStart: DayOfWeek,
        locale: Locale,
        widthDp: Float,
        density: Float,
        style: CardStyle,
    ): Bitmap? {
        val scale = capScale(widthDp * density, WEEKDAYS_DP * density)
        val w = (widthDp * density * scale).toInt()
        val h = (WEEKDAYS_DP * density * scale).toInt()
        if (w < 1 || h < 1) return null
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = style.muted
            textSize = 12f * density * scale
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val cell = w / 7f
        for (i in 0 until 7) {
            val label = weekStart.plus(i.toLong()).getDisplayName(TextStyle.NARROW, locale)
            canvas.drawText(label, cell * i + cell / 2, h * 0.72f, paint)
        }
        return bitmap
    }

    private fun grid(
        first: LocalDate,
        month: YearMonth,
        rows: Int,
        today: LocalDate,
        days: Map<Long, Day>,
        widthDp: Float,
        heightDp: Float,
        density: Float,
        style: CardStyle,
    ): Bitmap? {
        val scale = capScale(widthDp * density, heightDp * density)
        val px = density * scale
        val w = (widthDp * px).toInt()
        val h = (heightDp * px).toInt()
        if (w < 7 || h < rows) return null
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val cellW = w / 7f
        val cellH = h / rows.toFloat()

        val line = Paint().apply {
            color = style.cell
            strokeWidth = max(1f, px * 0.7f)
        }
        for (r in 0 until rows) canvas.drawLine(0f, cellH * r, w.toFloat(), cellH * r, line)
        for (c in 1 until 7) canvas.drawLine(cellW * c, 0f, cellW * c, h.toFloat(), line)

        val number = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 13f * px
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ACCENT }
        val chipFill = Paint(Paint.ANTI_ALIAS_FLAG)
        val chipText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 10f * px
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val more = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 9.5f * px
            color = style.muted
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        val chipH = CHIP_DP * px
        val gap = CHIP_GAP_DP * px
        val top = NUMBER_DP * px
        val slots = max(0, ((cellH - top - gap + gap) / (chipH + gap)).toInt())

        for (r in 0 until rows) {
            for (c in 0 until 7) {
                val date = first.plusDays((r * 7 + c).toLong())
                val x = cellW * c
                val y = cellH * r
                val outside = YearMonth.from(date) != month
                val dim = if (outside) 0.45f else 1f

                // Day number, ringed when it is today.
                val label = date.dayOfMonth.toString()
                val nx = x + 5f * px
                val baseline = y + 14.5f * px
                if (date == today) {
                    val width = number.measureText(label)
                    canvas.drawCircle(nx + width / 2, baseline - 4.5f * px, 9.5f * px, ring)
                    number.color = CardBitmaps.inkOn(ACCENT)
                } else {
                    number.color = CardBitmaps.withAlpha(style.content, dim)
                }
                canvas.drawText(label, nx, baseline, number)

                // Task labels: as many as fit, the last slot says "+n".
                val day = days[date.toEpochDay()] ?: continue
                if (slots == 0 || day.count == 0) continue
                val overflow = day.count > slots
                val shown = min(day.chips.size, if (overflow) slots - 1 else slots)
                var cy = y + top
                for (i in 0 until shown) {
                    val chip = day.chips[i]
                    val alpha = (if (chip.done) 0.4f else 1f) * dim
                    val rect = RectF(x + 2f * px, cy, x + cellW - 2f * px, cy + chipH)
                    chipFill.color = CardBitmaps.withAlpha(chip.color, alpha)
                    canvas.drawRoundRect(rect, 3f * px, 3f * px, chipFill)
                    chipText.color = CardBitmaps.withAlpha(CardBitmaps.inkOn(chip.color), alpha)
                    chipText.isStrikeThruText = chip.done
                    canvas.save()
                    canvas.clipRect(rect.left + 2f * px, rect.top, rect.right - 1f * px, rect.bottom)
                    canvas.drawText(chip.title, rect.left + 3f * px, rect.centerY() + 3.5f * px, chipText)
                    canvas.restore()
                    cy += chipH + gap
                }
                val hidden = day.count - shown
                if (hidden > 0) {
                    more.color = CardBitmaps.withAlpha(style.muted, dim)
                    canvas.drawText("+$hidden", x + 4f * px, cy + chipH * 0.75f, more)
                }
            }
        }
        return bitmap
    }

    /** Shrinks very large widgets' images to stay within memory limits. */
    private fun capScale(widthPx: Float, heightPx: Float): Float =
        min(1f, MAX_PX / max(widthPx, heightPx))

    private fun load(context: Context): JSONObject? = try {
        val raw = context.getSharedPreferences(DATA_PREFS, Context.MODE_PRIVATE)
            .getString(DATA_KEY, null)
        if (raw.isNullOrEmpty()) null else JSONObject(raw)
    } catch (e: Exception) {
        null
    }

    private fun parseDays(root: JSONObject?): Map<Long, Day> {
        val days = root?.optJSONObject("days") ?: return emptyMap()
        val out = HashMap<Long, Day>()
        for (key in days.keys()) {
            val epoch = key.toLongOrNull() ?: continue
            val entry = days.optJSONObject(key) ?: continue
            val list = entry.optJSONArray("c")
            val chips = ArrayList<Chip>()
            if (list != null) {
                for (i in 0 until list.length()) {
                    val chip = list.optJSONArray(i) ?: continue
                    chips.add(Chip(chip.optString(0), chip.optLong(1).toInt(), chip.optInt(2) == 1))
                }
            }
            out[epoch] = Day(entry.optInt("n", chips.size), chips)
        }
        return out
    }

    /** The app's day key, dd-MM-yyyy. */
    private fun key(date: LocalDate): String =
        String.format(Locale.ROOT, "%02d-%02d-%d", date.dayOfMonth, date.monthValue, date.year)

    private fun sizeOf(options: android.os.Bundle, key: String, fallback: Float): Float {
        val value = options.getInt(key, 0)
        return if (value > 0) value.toFloat() else fallback
    }

    private fun shiftIntent(context: Context, appWidgetId: Int, action: String): PendingIntent {
        val intent = Intent(context, CalendarWidgetProvider::class.java)
            .setAction(action)
            .putExtra(EXTRA_WIDGET, appWidgetId)
        val code = appWidgetId * 1000 + when (action) {
            ACTION_PREV -> 901
            ACTION_NEXT -> 902
            else -> 903
        }
        return PendingIntent.getBroadcast(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openPage(context: Context, appWidgetId: Int, slot: Int, page: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_PAGE, page)
        }
        return PendingIntent.getActivity(
            context,
            appWidgetId * 1000 + slot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
