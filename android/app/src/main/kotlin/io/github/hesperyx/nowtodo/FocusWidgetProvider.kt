package io.github.hesperyx.nowtodo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.widget.RemoteViews
import java.util.Calendar

/**
 * 桌面小组件。
 *
 * 它不认识数据库、也不认识 Flutter：只读应用推过来的一份快照（存在
 * [PREFS_NAME] 这个 SharedPreferences 里，写入方是 [HomeWidgetBridge]）。
 * 所以进程被杀掉之后桌面上显示的仍是上次推来的数字——这正是验收要的形态。
 *
 * 重画的时机只有两个：
 *  · 应用在跑时，专注状态一变 Dart 侧就推一份新的进来；
 *  · 应用不在时，系统按 `focus_widget_info.xml` 里的 `updatePeriodMillis`
 *    定期叫醒这里，读的还是上次那份快照。
 *
 * 快照里的日期是「本地零点毫秒」，与 Dart 侧的 `dayOnlyMillis` 对齐。跨过
 * 零点之后这份数据就属于昨天了，于是显示成「还没更新今天的记录」——
 * 让数字空着，也强过拿昨天的时长冒充今天。
 */
class FocusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        for (widgetId in widgetIds) {
            manager.updateAppWidget(widgetId, buildViews(context))
        }
    }

    companion object {
        const val PREFS_NAME = "now_todo_widget"

        // 快照的键名。这几个名字必须与 Dart 侧 buildWidgetPayload 发来的键
        // 完全一致——对不上不会报任何错，只会让桌面上一直空着。所以有一条
        // 测试直接读这个文件，逐个比对键名（test/android/home_widget_test.dart）。
        private const val KEY_HEADLINE = "headline"
        private const val KEY_CAPTION = "caption"
        private const val KEY_TODAY = "today"
        private const val KEY_LEVELS = "levels"

        private val BAR_IDS = intArrayOf(
            R.id.widget_bar_0,
            R.id.widget_bar_1,
            R.id.widget_bar_2,
            R.id.widget_bar_3,
            R.id.widget_bar_4,
            R.id.widget_bar_5,
            R.id.widget_bar_6,
        )

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        /** 让桌面上所有这块小组件立刻重画一遍。 */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FocusWidgetProvider::class.java))
            for (widgetId in ids) {
                manager.updateAppWidget(widgetId, buildViews(context))
            }
        }

        fun buildViews(context: Context): RemoteViews {
            val prefs = prefs(context)
            val look = WidgetLook.from(context, prefs)
            val views = RemoteViews(context.packageName, R.layout.focus_widget)
            val stale = prefs.getLong(KEY_TODAY, 0L) != startOfLocalDayMillis()

            views.setInt(R.id.widget_root, "setBackgroundColor", look.surface)
            views.setTextColor(R.id.widget_headline, look.title)
            views.setTextColor(R.id.widget_caption, look.body)
            views.setTextColor(R.id.widget_week_label, look.body)

            views.setTextViewText(
                R.id.widget_headline,
                if (stale) {
                    context.getString(R.string.focus_widget_stale_headline)
                } else {
                    prefs.getString(KEY_HEADLINE, "").orEmpty()
                },
            )
            views.setTextViewText(
                R.id.widget_caption,
                if (stale) {
                    context.getString(R.string.focus_widget_stale_caption)
                } else {
                    prefs.getString(KEY_CAPTION, "").orEmpty()
                },
            )

            val levels = prefs.getString(KEY_LEVELS, "").orEmpty()
                .split(',')
                .mapNotNull { it.trim().toIntOrNull() }
            for (index in BAR_IDS.indices) {
                val level = levels.getOrNull(index) ?: 0
                val color = look.palette[level.coerceIn(0, look.palette.size - 1)]
                views.setInt(BAR_IDS[index], "setBackgroundColor", color)
            }

            // 点哪儿都打开应用：小组件只有一块，没必要挑具体格子。
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return views
        }

        /** 今天零点那一刻的 epoch 毫秒，与 Dart 的 `dayOnlyMillis` 同义。 */
        private fun startOfLocalDayMillis(): Long {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            return calendar.timeInMillis
        }
    }
}

/**
 * 小组件要用的颜色，全部来自应用推来的快照。
 *
 * 浅色与深色两套都在快照里（Dart 侧按两套主题各算了一遍取色），这里只负责
 * 按系统当前是不是夜间挑一套：小组件跟的是系统的夜间模式，不是应用里那份
 * 设置——用户在系统里切模式的时候，应用很可能压根没在跑。
 *
 * 取不到时（还没推过任何快照）退回一组中性色，而不是去猜应用的主题色：
 * 那种时候画面上写的是「还没更新今天的记录」，配一块中性的底才对得上。
 */
private class WidgetLook(
    val palette: IntArray,
    val surface: Int,
    val title: Int,
    val body: Int,
) {
    companion object {
        private const val PALETTE_SIZE = 5

        // 键名一个不落地列出来，而不是拼 "surface$suffix" 这种动态字符串：
        // 有一条测试拿这八个名字去比对 Dart 发来的是什么（见
        // test/android/home_widget_test.dart），拼出来的名字它咬不住。
        private const val KEY_PALETTE_LIGHT = "paletteLight"
        private const val KEY_PALETTE_DARK = "paletteDark"
        private const val KEY_SURFACE_LIGHT = "surfaceLight"
        private const val KEY_SURFACE_DARK = "surfaceDark"
        private const val KEY_TITLE_LIGHT = "titleLight"
        private const val KEY_TITLE_DARK = "titleDark"
        private const val KEY_BODY_LIGHT = "bodyLight"
        private const val KEY_BODY_DARK = "bodyDark"

        fun from(context: Context, prefs: SharedPreferences): WidgetLook {
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val palette = parseColors(
                prefs.getString(if (night) KEY_PALETTE_DARK else KEY_PALETTE_LIGHT, null),
            )
            return WidgetLook(
                palette = if (palette.size >= PALETTE_SIZE) {
                    palette
                } else {
                    IntArray(PALETTE_SIZE) { 0xFF303030.toInt() }
                },
                surface = prefs.getInt(
                    if (night) KEY_SURFACE_DARK else KEY_SURFACE_LIGHT,
                    if (night) 0xFF171D1B.toInt() else 0xFFEFF5F1.toInt(),
                ),
                title = prefs.getInt(
                    if (night) KEY_TITLE_DARK else KEY_TITLE_LIGHT,
                    if (night) Color.WHITE else Color.BLACK,
                ),
                body = prefs.getInt(
                    if (night) KEY_BODY_DARK else KEY_BODY_LIGHT,
                    if (night) Color.LTGRAY else Color.DKGRAY,
                ),
            )
        }

        private fun parseColors(raw: String?): IntArray =
            raw.orEmpty().split(',').mapNotNull { it.trim().toIntOrNull() }.toIntArray()
    }
}
