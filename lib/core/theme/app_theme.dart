import 'package:flutter/material.dart';

import '../models/enums.dart';

/// 应用主题。
///
/// 只靠一个种子色生成整套配色（Material 3 的 `ColorScheme.fromSeed`），
/// 不手写几十个颜色值。理由：
///
/// - 手写配色几乎不可能在浅色和深色下同时满足对比度要求；
/// - 种子方案由框架保证对比度，也让 `darkTheme` 不会成为「没人测过的那套界面」；
/// - PRD 里「主题色自定义」是增强项，届时换掉 [seed] 就能整体生效。
abstract final class AppTheme {
  /// 种子色：低饱和深青。
  ///
  /// 选它是因为这是个一天要打开几十次的应用——配色应当安静，
  /// 不能像待办清单本身那样抢注意力。
  static const Color seed = Color(0xFF2E6B5E);

  /// 内容最大宽度。桌面端窗口拉宽后仍保持可读的排版宽度。
  static const double contentMaxWidth = 720;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  /// 把设置里的 [ThemeModeSetting] 映射成 Flutter 的 [ThemeMode]。
  static ThemeMode resolve(ThemeModeSetting setting) => switch (setting) {
    ThemeModeSetting.system => ThemeMode.system,
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
  };

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      // 显式指定，避免跟随系统默认值造成两端不一致。
      brightness: brightness,
      // 浅色下给背景一点色偏，避免大片纯白在暗光环境下刺眼。
      scaffoldBackgroundColor: isDark
          ? scheme.surface
          : scheme.surfaceContainerLowest,

      appBarTheme: AppBarThemeData(
        backgroundColor: isDark
            ? scheme.surface
            : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // 待办列表几乎全是卡片，用描边代替阴影：滚动时不会有一堆浮起来的方块。
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      listTileTheme: ListTileThemeData(
        // 让勾选框与标题在视觉上对齐。
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.4 : 0.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // 扩展式 FAB：显式写出「新建任务」，比一个 + 号少一次猜测。
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: isDark
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: scheme.surfaceContainerLow,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      ),

      visualDensity: VisualDensity.standard,
    );
  }
}
