import 'package:drift/drift.dart';

import '../../../core/models/enums.dart';

/// 应用设置。
///
/// **单行表**：全表恒定只有 `id = 1` 这一行，由 `SettingsRepository` 保证。
/// 用固定列而不是「键值对表」，是一个有意的取舍：
///
/// - 列有类型，`themeMode` 存出来就是枚举，不用在每个使用处解析字符串；
/// - 新增设置的代价是一次 `addColumn` 迁移——这反而是好事，
///   它会强迫你回答「旧用户的这行数据该填什么」，而不是默默取默认值。
///
/// 代价是设置项变多以后表会变宽。首版的设置项屈指可数，远没到那个程度。
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  /// 恒为 `1`。见类文档。
  IntColumn get id => integer().withDefault(const Constant(1))();

  IntColumn get themeMode =>
      intEnum<ThemeModeSetting>().withDefault(const Constant(0))();

  IntColumn get defaultView =>
      intEnum<DefaultView>().withDefault(const Constant(0))();

  /// 总开关。关掉后不再注册任何系统通知，但已配置的 [Reminders] 行保留。
  ///
  /// 与「提醒本身被禁用」是两件事：前者是全局态度，后者是单条配置。
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// 首次启动完成时间。`null` 表示还没走过初始化。
  ///
  /// 用它判断要不要建内置清单、要不要显示欢迎引导——
  /// 比「表里有没有数据」可靠，因为用户可能把内置数据全删了。
  IntColumn get initializedAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
