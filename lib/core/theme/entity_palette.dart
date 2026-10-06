import 'package:flutter/material.dart';

/// 清单与标签共用的颜色。
///
/// 只做一档颜色，不做浅色 / 深色两套：颜色是用户**选出来的一个值**，
/// 换主题时它应该还是同一个颜色，而不是悄悄变成另一种。所以这八个都取
/// 中间调，压在浅色和深色两种背景上都看得清。
///
/// 没做成 `Color` 常量列表让调用方随便传：库里存的是 ARGB 整数
/// （`Color.toARGB32()`），入口收窄成一个有限集合，是为了让「改色」
/// 这个操作永远是可逆的——用户挑回原来那个色就能回到原样。
///
/// 八个色值不是随手挑的：M6 深色模式走查时逐个量过对比度，每个都在浅色与
/// 深色**两种**卡片底色上达到 3.9:1 以上（非文本图形的下限是 3:1），
/// 色块上的对勾也有 4.3:1。这条约束由 `test/core/theme/entity_palette_test.dart`
/// 守着，改色值前先跑它。
abstract final class EntityPalette {
  /// 可选的颜色。顺序就是界面上色块的顺序。
  static const List<Color> colors = <Color>[
    Color(0xFF4F8378), // 墨绿（主题色的浅一档，深色卡片上才看得见）
    Color(0xFF4D7CAE), // 蓝
    Color(0xFF7E70B4), // 紫
    Color(0xFFB95C6D), // 红
    Color(0xFFA86B2B), // 橙
    Color(0xFF7D7D32), // 橄榄
    Color(0xFF2C8585), // 青
    Color(0xFF797979), // 灰
  ];

  /// 把库里存的整数还原成颜色。`null` 表示「没挑过」。
  ///
  /// 不做「不在调色板里就当没挑过」的校验：真出现那种值，说明数据是从
  /// 别的版本导进来的，照原样显示比默默丢掉更诚实。
  static Color? resolve(int? argb) => argb == null ? null : Color(argb);

  /// 色块上的对勾颜色。深色系上用白勾，浅色系上用黑勾。
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
