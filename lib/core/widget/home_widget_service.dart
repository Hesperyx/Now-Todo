/// 把快照送到桌面小组件。
///
/// 只有 Android 有小组件；桌面构建与测试走 [NoopHomeWidgetService]，
/// 和通知服务同一套路数——在一处判断平台，而不是到处 try/catch。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/focus_stats.dart';
import '../theme/app_theme.dart';
import '../theme/heat_colors.dart';
import 'home_widget_snapshot.dart';

/// 小组件的写入接口。
abstract interface class HomeWidgetService {
  Future<void> update(HomeWidgetSnapshot snapshot);
}

/// 什么都不做的实现。
class NoopHomeWidgetService implements HomeWidgetService {
  const NoopHomeWidgetService();

  @override
  Future<void> update(HomeWidgetSnapshot snapshot) async {}
}

/// 真实实现：把快照交给 Android 侧的 `AppWidgetProvider`。
class MethodChannelHomeWidgetService implements HomeWidgetService {
  MethodChannelHomeWidgetService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  final MethodChannel _channel;

  /// 通道名。Kotlin 侧硬编码了同一个字符串，写错的症状是「点了开始专注，
  /// 桌面上什么也没变」——`test/android/home_widget_declaration_test.dart`
  /// 会把两边对起来。
  static const String channelName = 'now_todo/widget';

  /// 方法名。只有一个：整份快照覆盖式写入，不做增量。
  static const String updateMethod = 'update';

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> update(HomeWidgetSnapshot snapshot) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        updateMethod,
        buildWidgetPayload(snapshot),
      );
    } on MissingPluginException {
      // 平台侧还没挂上（热重载早期、或者这一版没带 Kotlin 代码）。
      // 小组件是增强功能，缺了它任务与专注本身照常。
    } on PlatformException catch (error) {
      debugPrint('小组件刷新失败：$error');
    }
  }
}

/// 某一套主题下小组件要用的颜色。
///
/// 颜色在 Dart 侧算好再传：启动器画小组件时进程里没有 Flutter，拿不到
/// `ColorScheme`；让它自己写死一套颜色，就等于同一个配色有了两个出处。
typedef WidgetLook = ({
  /// 五档底色，顺序同 [kFocusHeatOrder]。
  List<int> palette,
  int surface,
  int title,
  int body,
});

/// 小组件上的五档底色。
///
/// 与应用里的热力图有一个刻意的差别：`none` 档在应用里是「浅底 + 描边」，
/// 小组件的柱子只能填一个颜色、描不了边，所以这里直接用描边色填满。
List<int> widgetPalette(ColorScheme scheme) => <int>[
  scheme.outlineVariant.toARGB32(),
  for (final FocusHeat heat in kFocusHeatOrder.skip(1))
    focusHeatColor(scheme, heat).toARGB32(),
];

WidgetLook _look(ColorScheme scheme) => (
  palette: widgetPalette(scheme),
  surface: scheme.surfaceContainerLow.toARGB32(),
  title: scheme.onSurface.toARGB32(),
  body: scheme.onSurfaceVariant.toARGB32(),
);

/// 两套配色算一次就够。顶层 `final` 是惰性初始化：没推送过快照就不会去
/// 建这两份 `ThemeData`。
final WidgetLook _lightLook = _look(AppTheme.light().colorScheme);
final WidgetLook _darkLook = _look(AppTheme.dark().colorScheme);

/// 快照 + 配色 → 平台侧要的 map。
///
/// 两套配色一起发过去，由 Kotlin 侧按系统深浅色挑一套：小组件的深浅色跟的是
/// 系统，不是应用里那份「跟随系统 / 浅色 / 深色」的设置，用户在系统里切夜间
/// 模式时应用可能压根没在跑。
Map<String, Object?> buildWidgetPayload(HomeWidgetSnapshot snapshot) {
  return <String, Object?>{
    ...snapshot.toMap(),
    'paletteLight': _lightLook.palette,
    'paletteDark': _darkLook.palette,
    'surfaceLight': _lightLook.surface,
    'surfaceDark': _darkLook.surface,
    'titleLight': _lightLook.title,
    'titleDark': _darkLook.title,
    'bodyLight': _lightLook.body,
    'bodyDark': _darkLook.body,
  };
}
