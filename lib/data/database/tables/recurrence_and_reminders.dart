import 'package:drift/drift.dart';

import '../../../core/models/enums.dart';
import 'tasks.dart';

/// 重复规则。
///
/// 单独一张表而不是把字段内联进 `tasks`：一次性任务占了绝大多数，
/// 内联会让每行都带一堆恒为 `NULL` 的列，而且规则本身是可以被
/// 未来「编辑重复系列」功能独立引用的实体。
///
/// `byWeekday` / `byMonthDay` 用**逗号分隔的十进制数字文本**存，
/// 而不是位掩码或 JSON：
///
/// - 导出成 JSON 时人能直接读懂，出问题好排查；
/// - 位掩码一旦定错就再也改不动；
/// - 解析成本可以忽略（一行最多几个数字）。
class RecurrenceRules extends Table {
  @override
  String get tableName => 'recurrence_rules';

  TextColumn get id => text()();

  IntColumn get frequency => intEnum<RecurrenceFrequency>()();

  /// 间隔倍数。`frequency = weekly` 且 `interval = 2` 表示「每两周」。
  /// 恒 `>= 1`，由应用层保证（数据库 CHECK 约束见迁移脚本）。
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// 每周重复时生效：`1`=周一 … `7`=周日，逗号分隔，如 `"1,3,5"`。
  /// 为空表示「与起始日同一星期几」。
  TextColumn get byWeekday => text().nullable()();

  /// 每月重复时生效：`1`…`31`，逗号分隔，如 `"1,15"`。
  /// 指定 29/30/31 而目标月份没有那天时，落到该月最后一天。
  TextColumn get byMonthDay => text().nullable()();

  /// 重复的结束日期（本地零点，UTC 毫秒）。`null` = 永不结束。
  ///
  /// 不设默认上界：用户没说要停就一直重复。但 UI 上会提示「无限重复」，
  /// 免得用户以为设完就完事了。
  IntColumn get endDate => integer().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 提醒。
///
/// 一个任务可以有多条提醒（例如「提前一天」+「当天早上」）。
/// 与 `flutter_local_notifications` 的对应关系：一行 = 一个已注册的
/// 系统通知，`id` 的哈希值作为通知 id，取消时按同一算法反查。
///
/// 通知**不写在数据库里就发不出去**——应用被杀掉后系统仍会按时弹，
/// 这正是我们要的。反过来，用户改时间时必须显式取消旧的，见
/// `ReminderScheduler`。
@TableIndex(name: 'reminders_task_id', columns: {#taskId})
@TableIndex(name: 'reminders_remind_at', columns: {#remindAt})
class Reminders extends Table {
  @override
  String get tableName => 'reminders';

  TextColumn get id => text()();

  /// 所属任务。任务删除时连带删除提醒。
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// 提醒时刻，UTC 毫秒。
  IntColumn get remindAt => integer()();

  IntColumn get repeatType =>
      intEnum<ReminderRepeatType>().withDefault(const Constant(0))();

  /// 关掉但保留配置。`false` 的提醒不会被注册到系统。
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
