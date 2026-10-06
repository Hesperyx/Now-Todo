/// 热力五档的配色。
///
/// 原先它住在热力图那个文件里；桌面小组件也要画同样五档之后搬来 core：
/// 两边各写一份公式，就总有一处会忘了改，而「同一个颜色在两处含义不同」
/// 是最难被发现的那种错。
library;

import 'package:flutter/material.dart';

import '../focus/focus_stats.dart';

/// 一格的底色。
///
/// 五个档位里 [FocusHeat.none] 是**唯一带边框**的：它表示「这天什么都没有」，
/// 与表示「来过但没计时」的 [FocusHeat.zero] 必须一眼能分开，否则用户会以为
/// 自己的记录丢了。
Color focusHeatColor(ColorScheme scheme, FocusHeat heat) => switch (heat) {
  FocusHeat.none => scheme.surfaceContainerHighest,
  FocusHeat.zero => scheme.primary.withValues(alpha: 0.12),
  FocusHeat.light => scheme.primary.withValues(alpha: 0.32),
  FocusHeat.medium => scheme.primary.withValues(alpha: 0.62),
  FocusHeat.heavy => scheme.primary,
};

/// 一格里文字的颜色：底色越深越要换成反色。
Color onFocusHeatColor(ColorScheme scheme, FocusHeat heat) =>
    heat == FocusHeat.heavy ? scheme.onPrimary : scheme.onSurfaceVariant;

/// 档位的固定顺序。
///
/// 这不仅是个排列：桌面小组件只拿到一串下标（`0` 到 `4`），Kotlin 侧按
/// 这个顺序查颜色。改动顺序会让已经装在桌面上的旧版本小组件把颜色认错，
/// 所以 `test/core/theme/heat_colors_test.dart` 把它咬住了。
const List<FocusHeat> kFocusHeatOrder = <FocusHeat>[
  FocusHeat.none,
  FocusHeat.zero,
  FocusHeat.light,
  FocusHeat.medium,
  FocusHeat.heavy,
];

/// 五档底色的 ARGB 整数，按 [kFocusHeatOrder] 排。
///
/// 小组件由启动器绘制，进程里没有 Flutter 的 `ColorScheme`，只能把颜色
/// 提前算好传过去。
List<int> focusHeatPalette(ColorScheme scheme) => <int>[
  for (final FocusHeat heat in kFocusHeatOrder)
    focusHeatColor(scheme, heat).toARGB32(),
];
