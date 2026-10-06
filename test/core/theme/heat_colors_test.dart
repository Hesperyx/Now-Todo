import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/theme/app_theme.dart';
import 'package:now_todo/core/theme/heat_colors.dart';

void main() {
  group('kFocusHeatOrder · 顺序就是接口', () {
    test('与 FocusHeat 的声明顺序完全一致', () {
      // 小组件拿到的是 heatOf(day).index，Kotlin 侧按 kFocusHeatOrder 查颜色。
      // 这两个顺序一旦分家，桌面上那块卡片就会把「有记录没计时」画成「满一小时」。
      expect(kFocusHeatOrder, FocusHeat.values);
    });

    test('每一档的枚举下标等于它在表里的下标', () {
      for (final FocusHeat heat in FocusHeat.values) {
        expect(kFocusHeatOrder[heat.index], heat, reason: '$heat');
      }
    });

    test('没有重复档位，五档一个不少', () {
      expect(kFocusHeatOrder.toSet().length, FocusHeat.values.length);
      expect(kFocusHeatOrder.length, 5);
    });
  });

  group('focusHeatPalette · 传给平台侧的颜色表', () {
    final ColorScheme light = AppTheme.light().colorScheme;
    final ColorScheme dark = AppTheme.dark().colorScheme;

    test('长度与 kFocusHeatOrder 对齐，按下标取得到颜色', () {
      expect(focusHeatPalette(light).length, kFocusHeatOrder.length);
      for (int index = 0; index < kFocusHeatOrder.length; index++) {
        expect(
          focusHeatPalette(light)[index],
          focusHeatColor(light, kFocusHeatOrder[index]).toARGB32(),
          reason: '第 $index 档',
        );
      }
    });

    test('两端的档位是不透明的，中间三档留着透明度', () {
      // 中间三档是主色加透明度，小组件那边画在卡片底色上，与热力图一致；
      // 两端是实色（容器色 / 主色），不透明。
      final List<int> palette = focusHeatPalette(light);
      int alphaOf(int index) => palette[index] >> 24 & 0xFF;

      expect(alphaOf(0), 0xFF, reason: 'none');
      expect(alphaOf(4), 0xFF, reason: 'heavy');
      for (final int index in <int>[1, 2, 3]) {
        expect(alphaOf(index), greaterThan(0), reason: '第 $index 档不该是全透明');
        expect(alphaOf(index), lessThan(0xFF), reason: '第 $index 档该留着透明度');
      }
    });

    test('深浅两套不一样', () {
      expect(focusHeatPalette(light), isNot(focusHeatPalette(dark)));
    });
  });

  group('focusHeatColor · 五档能分开', () {
    final ColorScheme scheme = AppTheme.light().colorScheme;

    test('none 用容器色、heavy 用主色，两端不重样', () {
      expect(
        focusHeatColor(scheme, FocusHeat.none),
        scheme.surfaceContainerHighest,
      );
      expect(focusHeatColor(scheme, FocusHeat.heavy), scheme.primary);
    });

    test('zero / light / medium 是同一主色的三档透明度，依次变浓', () {
      double alphaOf(FocusHeat heat) => focusHeatColor(scheme, heat).a;

      expect(alphaOf(FocusHeat.zero), lessThan(alphaOf(FocusHeat.light)));
      expect(alphaOf(FocusHeat.light), lessThan(alphaOf(FocusHeat.medium)));
      expect(alphaOf(FocusHeat.medium), lessThan(alphaOf(FocusHeat.heavy)));
    });

    test('五档两两不同', () {
      final Set<int> colors = <int>{
        for (final FocusHeat heat in FocusHeat.values)
          focusHeatColor(scheme, heat).toARGB32(),
      };
      expect(colors.length, FocusHeat.values.length);
    });
  });

  group('onFocusHeatColor · 一格里文字的颜色', () {
    final ColorScheme scheme = AppTheme.light().colorScheme;

    test('只有最浓的那一档换反色', () {
      expect(onFocusHeatColor(scheme, FocusHeat.heavy), scheme.onPrimary);
      for (final FocusHeat heat in FocusHeat.values) {
        if (heat == FocusHeat.heavy) {
          continue;
        }
        expect(
          onFocusHeatColor(scheme, heat),
          scheme.onSurfaceVariant,
          reason: '$heat',
        );
      }
    });

    test('反色与底色不是同一个颜色', () {
      expect(
        onFocusHeatColor(scheme, FocusHeat.heavy),
        isNot(focusHeatColor(scheme, FocusHeat.heavy)),
      );
    });
  });
}
