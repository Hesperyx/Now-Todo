import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/theme/app_theme.dart';
import 'package:now_todo/core/theme/entity_palette.dart';

/// 两色的对比度（WCAG 2.x）。
double ratio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG 的两条线：正文 4.5:1，非文本的图形（图标、圆点、描边）3:1。
  const double textFloor = 4.5;
  const double graphicsFloor = 3.0;

  group('调色板', () {
    final ColorScheme light = AppTheme.light().colorScheme;
    final ColorScheme dark = AppTheme.dark().colorScheme;

    test('八个颜色互不相同', () {
      // 顺序就是界面上的顺序；有两个一模一样，用户会以为少了一个色块。
      final Set<int> argb = <int>{
        for (final Color c in EntityPalette.colors) c.toARGB32(),
      };
      expect(argb, hasLength(EntityPalette.colors.length));
    });

    test('每个颜色在浅色卡片上都看得见', () {
      for (final Color c in EntityPalette.colors) {
        expect(
          ratio(c, light.surfaceContainerLow),
          greaterThanOrEqualTo(graphicsFloor),
          reason: '颜色 ${c.toARGB32().toRadixString(16)} 在浅色卡片上对比度不足',
        );
      }
    });

    test('每个颜色在深色卡片上都看得见', () {
      for (final Color c in EntityPalette.colors) {
        expect(
          ratio(c, dark.surfaceContainerLow),
          greaterThanOrEqualTo(graphicsFloor),
          reason: '颜色 ${c.toARGB32().toRadixString(16)} 在深色卡片上对比度不足',
        );
      }
    });

    test('色块上的对勾在两种主题下都能看清', () {
      for (final Color c in EntityPalette.colors) {
        expect(
          ratio(EntityPalette.onColor(c), c),
          greaterThanOrEqualTo(graphicsFloor),
          reason: '颜色 ${c.toARGB32().toRadixString(16)} 上的对勾对比度不足',
        );
      }
    });

    test('resolve：没挑过是 null，挑过的原样返回', () {
      expect(EntityPalette.resolve(null), isNull);
      expect(EntityPalette.resolve(0xFF4F8378), const Color(0xFF4F8378));
      // 不在调色板里的值也照原样显示——它多半来自别的版本导进来的数据。
      expect(EntityPalette.resolve(0xFF123456), const Color(0xFF123456));
    });
  });

  group('主题配色', () {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      final String name = theme.brightness == Brightness.dark ? '深色' : '浅色';
      final ColorScheme scheme = theme.colorScheme;
      final Color card = scheme.surfaceContainerLow;

      test('$name：正文与次要文字在卡片上都达到 4.5:1', () {
        expect(ratio(scheme.onSurface, card), greaterThanOrEqualTo(textFloor));
        expect(
          ratio(scheme.onSurfaceVariant, card),
          greaterThanOrEqualTo(textFloor),
          reason: '次要文字用 onSurfaceVariant，日期、标签、子任务数都走它',
        );
      });

      test('$name：当文字用的强调色也达到 4.5:1', () {
        // 首页把这些当小字用：逾期 = error、优先级 = primary/tertiary/error、
        // 专注页的计时数字 = primary。它们不是装饰，是信息本身。
        expect(ratio(scheme.error, card), greaterThanOrEqualTo(textFloor));
        expect(ratio(scheme.primary, card), greaterThanOrEqualTo(textFloor));
        expect(ratio(scheme.tertiary, card), greaterThanOrEqualTo(textFloor));
      });

      test('$name：描边与分隔线至少 3:1', () {
        expect(
          ratio(scheme.outline, card),
          greaterThanOrEqualTo(graphicsFloor),
        );
        expect(
          ratio(scheme.outlineVariant, scheme.surfaceContainer),
          greaterThanOrEqualTo(1.3),
          reason:
              '分隔线是装饰，WCAG 不管它，但它必须和底色分得开。'
              'Material 3 的浅色 outlineVariant 本来就淡（实测 1.46），'
              '这里只守「不是看不见」这条底线',
        );
      });

      test('$name：填充按钮上的文字达到 4.5:1', () {
        expect(
          ratio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(textFloor),
        );
        expect(
          ratio(scheme.onError, scheme.error),
          greaterThanOrEqualTo(textFloor),
        );
        expect(
          ratio(scheme.onSurface, scheme.surfaceContainerHighest),
          greaterThanOrEqualTo(textFloor),
          reason: '输入框的填充色是 surfaceContainerHighest',
        );
      });
    }
  });
}
