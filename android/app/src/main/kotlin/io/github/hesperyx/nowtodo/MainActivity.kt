package io.github.hesperyx.nowtodo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 桌面小组件的那条写入通道，见 HomeWidgetBridge。
        // 应用没在跑时它当然也不在，那时小组件显示的是上次推来的快照。
        HomeWidgetBridge.register(flutterEngine, applicationContext)
    }
}
