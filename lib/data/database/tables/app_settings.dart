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

  /// 强提醒：到点后持续响铃，直到用户处理掉这条通知。
  ///
  /// 默认**关**。它会一直响，默认开启对一个待办应用来说太吵了；
  /// 而且系统勿扰与静音会压制它，用户以为「开了就一定能叫醒」时
  /// 反而更容易误事，所以必须是用户主动选的。
  BoolColumn get strongReminders =>
      boolean().withDefault(const Constant(false))();

  // ────────────────────────── 专注计时 ──────────────────────────
  //
  // 下面这些默认值是「标准番茄钟」那一套（25 / 5 / 15，四轮一长休）。
  // 之所以给默认值而不是留空让用户在设置里填：第一次点「开始专注」的人
  // 应该直接就有一个能跑的配置，而不是先被要求做一次设置。

  /// 一轮专注的分钟数。
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();

  /// 短休息的分钟数。
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();

  /// 长休息的分钟数。
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();

  /// 几轮专注之后接一次长休息。
  IntColumn get roundsBeforeLongBreak =>
      integer().withDefault(const Constant(4))();

  /// 一轮结束后是否自动开始下一轮。
  ///
  /// 默认**关**：自动接续意味着用户离开工位后计时器还在自己往下跑，
  /// 记下来的「专注」会变成一段没人专注的时间。
  BoolColumn get autoStartNext =>
      boolean().withDefault(const Constant(false))();

  /// 默认的计时模式。`1` = `FocusTimerMode.countDown`（枚举是追加式的，
  /// 倒计时不是第 0 个，所以这里只能写裸值）。
  IntColumn get defaultTimerMode =>
      intEnum<FocusTimerMode>().withDefault(const Constant(1))();

  /// 午夜模式：凌晨开始的会话算作前一天。
  ///
  /// 默认**关**。对作息正常的人是纯粹的噪音，对熬夜的人才是刚需。
  BoolColumn get midnightMode => boolean().withDefault(const Constant(false))();

  /// 午夜模式的边界小时：本地时刻小于它的算前一天。默认 4 点。
  IntColumn get midnightEndHour => integer().withDefault(const Constant(4))();

  /// 首次启动完成时间。`null` 表示还没走过初始化。
  ///
  /// 用它判断要不要建内置清单、要不要显示欢迎引导——
  /// 比「表里有没有数据」可靠，因为用户可能把内置数据全删了。
  IntColumn get initializedAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
