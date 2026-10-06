import 'package:drift/drift.dart';

import '../../../core/models/enums.dart';
import 'tasks.dart';

/// 一次专注 / 休息会话。
///
/// 这个表的职责是**把「时间花在哪」这件事如实记下来**，不做任何汇总。
/// 统计（`lib/core/focus/focus_stats.dart`）全部是读这张表的纯函数，
/// 所以没有 `daily_stats` 之类的汇总表——汇总表会引出「什么时候重算」
/// 「数据不一致怎么办」两个新问题，而一年 365 天的聚合在本机是毫秒级的。
///
/// 几个刻意的设计决定：
///
/// - **`endedAt` 为 `null` 表示「正在进行中」**，不做 `isRunning` 布尔列。
///   两列表达同一件事迟早会互相矛盾。
/// - **`taskId` 可空且 `ON DELETE SET NULL`**：删任务不该抹掉已经专注过的历史，
///   那段时间是真花掉的。挂空之后统计照常算，只是不再归属某个任务。
/// - **时间全部存 UTC 毫秒**，见 `lib/core/utils/time.dart`。
/// - **[logicalDate] 在写入时冻结**，不由读取时算。午夜模式（凌晨算前一天）
///   与「午夜边界小时」是用户设置，改设置不该让昨天的记录整体搬家。
/// - **[actualSeconds] 是结束时算好的实际时长**，与 [plannedSeconds] 分开存。
///   倒计时提前放弃时两者不等，统计要的是实际值。
@TableIndex(name: 'focus_sessions_logical_date', columns: {#logicalDate})
@TableIndex(name: 'focus_sessions_task_id', columns: {#taskId})
@TableIndex(name: 'focus_sessions_started_at', columns: {#startedAt})
class FocusSessions extends Table {
  @override
  String get tableName => 'focus_sessions';

  TextColumn get id => text()();

  /// 归属任务。`null` = 没挂任务的自由专注。
  TextColumn get taskId =>
      text().nullable().references(Tasks, #id, onDelete: KeyAction.setNull)();

  /// 会话开始时刻，UTC 毫秒。
  IntColumn get startedAt => integer()();

  /// 结束时刻。`null` 表示还在进行中。
  IntColumn get endedAt => integer().nullable()();

  /// 累计暂停时长（毫秒）。与 `FocusTimerState.pausedMillis` 直接对应。
  ///
  /// **只含已经结束的暂停**。正在进行中的那次暂停由 [pausedAt] 单独表示，
  /// 因为它的时长要到恢复时才确定。
  IntColumn get pausedMillis => integer().withDefault(const Constant(0))();

  /// 当前这次暂停的开始时刻。非空 = 会话正暂停着。
  ///
  /// **这一列不在最初的设计稿里，是写实现时补的**：只有 [pausedMillis]
  /// 的话，用户在暂停状态下被系统杀进程，重开后只能看到「从开始就一直跑着」，
  /// 于是整段暂停时间会被安静地算成专注时间——而杀进程恰恰是这套设计
  /// 必须扛住的场景。表随 v3 一起发布，此刻加列不需要额外迁移。
  IntColumn get pausedAt => integer().nullable()();

  /// 计划时长（秒）。正计时模式为 `null`。
  IntColumn get plannedSeconds => integer().nullable()();

  /// 实际时长（秒）。结束时写入，不含暂停。
  IntColumn get actualSeconds => integer().withDefault(const Constant(0))();

  /// 这是专注还是休息。
  IntColumn get kind =>
      intEnum<FocusSessionKind>().withDefault(const Constant(0))();

  /// 正计时还是倒计时。
  IntColumn get timerMode =>
      intEnum<FocusTimerMode>().withDefault(const Constant(1))();

  /// 归属的逻辑日（本地零点毫秒）。写入时按当时的设置冻结，见类文档。
  IntColumn get logicalDate => integer()();

  /// 是否走满了计划时长。正计时模式结束时为 `false`——它没有「走满」这回事。
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// 这一笔的备注，会话结束后补填。
  ///
  /// **不在最初的设计稿里**：F3 的「记一笔」要求会话结束后可以写备注，
  /// 而表里没有地方放。趁 v3 还没发布加进来，比之后为它单独开一次迁移便宜。
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
