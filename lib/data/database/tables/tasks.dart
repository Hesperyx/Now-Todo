import 'package:drift/drift.dart';

import '../../../core/models/enums.dart';
import 'recurrence_and_reminders.dart';
import 'task_lists.dart';

/// 任务。整张表就是产品本身。
///
/// 几个刻意的设计决定：
///
/// - **`id` 由客户端生成**，不是自增整数。见 `lib/core/utils/ids.dart`。
/// - **`listId` 可空**，且清单被删时置空而不是连带删除任务。
///   删一个清单不该让里面的任务凭空消失——那是最容易招骂的行为。
/// - **时间全部存 UTC 毫秒**，见 `lib/core/utils/time.dart`。
/// - **首版硬删除**。不做软删除（`deletedAt`），因为「回收站」会引出
///   一整套新的 UI 与生命周期问题，而 PRD 首版范围里没有它。
@TableIndex(name: 'tasks_status', columns: {#status})
@TableIndex(name: 'tasks_due_date', columns: {#dueDate})
@TableIndex(name: 'tasks_list_id', columns: {#listId})
@TableIndex(name: 'tasks_recurrence_rule_id', columns: {#recurrenceRuleId})
class Tasks extends Table {
  @override
  String get tableName => 'tasks';

  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  /// 备注。允许 Markdown 原文，但首版只按纯文本渲染。
  TextColumn get note => text().nullable()();

  /// 截止时间，UTC 毫秒。`null` 表示没有截止日期。
  IntColumn get dueDate => integer().nullable()();

  /// [dueDate] 是否精确到时刻。
  ///
  /// `false` = 用户只选了「哪一天」，此时 [dueDate] 恒为本地零点。
  /// 这个标记主要服务于导出格式：导入方需要知道该按日期还是按时刻来理解。
  BoolColumn get dueDateHasTime =>
      boolean().withDefault(const Constant(false))();

  IntColumn get priority =>
      intEnum<TaskPriority>().withDefault(const Constant(0))();

  IntColumn get status =>
      intEnum<TaskStatus>().withDefault(const Constant(0))();

  /// 所属清单。清单删除时置空（`SET NULL`），任务保留。
  TextColumn get listId => text().nullable().references(
    TaskLists,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 所属重复规则。`null` 表示一次性任务。
  ///
  /// 重复任务**不是**在数据库里预先展开成无数行，而是「一个规则 + 一个
  /// 当前实例」。完成当前实例时，由应用层按规则算出下一次并重写本行。
  /// 理由见 `docs/ARCHITECTURE.md` §7：预先展开会让「改一次重复设置」
  /// 变成批量改一堆行，且没有自然的上界。
  TextColumn get recurrenceRuleId => text().nullable().references(
    RecurrenceRules,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 完成时刻。`status` 回到 pending 时会被清空。
  IntColumn get completedAt => integer().nullable()();

  /// 预估要花几个番茄钟。
  ///
  /// **可空**，而且「没估过」与「估了 0 个」是两件事：前者不该在界面上
  /// 显示进度条，后者是一个明确的「这个任务不用专注」。用 0 表示「没估过」
  /// 会把这两个状态压成一个，之后再想分开就得做数据迁移。
  IntColumn get estimatedPomodoros => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
