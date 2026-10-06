package io.github.hesperyx.nowtodo

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart 与小组件之间的那条通道。
 *
 * 只有一件事：把一份算好的快照写进 SharedPreferences，再让桌面上那几块立刻
 * 重画。**不做增量**——每次都是整份覆盖写，省掉「上一次的第五格还留着」
 * 这类只有用户会发现的错。
 *
 * 通道名与方法名要和 Dart 侧 `MethodChannelHomeWidgetService` 里的一致；
 * 对不上不会报错，只会让小组件一直停在空状态（有测试逐个比对，见
 * test/android/home_widget_test.dart）。
 */
object HomeWidgetBridge {
    const val CHANNEL_NAME = "now_todo/widget"
    private const val METHOD_UPDATE = "update"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                if (call.method != METHOD_UPDATE) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    write(context, call)
                    result.success(null)
                } catch (error: Exception) {
                    // 写快照失败不该把 Dart 那边炸掉：小组件是增强功能，
                    // 应用照常用。Dart 侧会把这句打进日志。
                    result.error("widget_update_failed", error.message, null)
                }
            }
    }

    private fun write(context: Context, call: MethodCall) {
        val editor = FocusWidgetProvider.prefs(context).edit()
        editor.putLong("today", call.long("today"))
        editor.putLong("seconds", call.long("seconds"))
        editor.putInt("sessions", call.long("sessions").toInt())
        editor.putString("headline", call.argument<String>("headline"))
        editor.putString("caption", call.argument<String>("caption"))
        // 两个列表都存成逗号分隔的字符串：SharedPreferences 的字符串集合会把
        // 顺序弄丢，而这两个列表里数字的顺序就是它们的含义。
        editor.putString("levels", call.intList("levels").joinToString(","))
        editor.putString("paletteLight", call.intList("paletteLight").joinToString(","))
        editor.putString("paletteDark", call.intList("paletteDark").joinToString(","))
        editor.putInt("surfaceLight", call.long("surfaceLight").toInt())
        editor.putInt("surfaceDark", call.long("surfaceDark").toInt())
        editor.putInt("titleLight", call.long("titleLight").toInt())
        editor.putInt("titleDark", call.long("titleDark").toInt())
        editor.putInt("bodyLight", call.long("bodyLight").toInt())
        editor.putInt("bodyDark", call.long("bodyDark").toInt())
        editor.apply()
        FocusWidgetProvider.refresh(context)
    }

    /** Dart 的整数过来了是 Number；缺失或类型不对时按 0 处理。 */
    private fun MethodCall.long(key: String): Long = argument<Number>(key)?.toLong() ?: 0L

    private fun MethodCall.intList(key: String): List<Int> =
        argument<List<Number>>(key)?.map { it.toInt() } ?: emptyList()
}
