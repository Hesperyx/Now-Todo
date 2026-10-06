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
  /// 恒 `>= 1`，由应用层保证（`RecurrenceRule.normalized()` 会在写入前收口）。
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// 系列的锚点（本地时间的 UTC 毫秒）：整个系列的日期都由它推算。
  ///
  /// 存锚点而不是「上一条实例的日期」是刻意的：某一条被单独挪到下周三，
  /// 不该把「每周一」这个系列从此拖成周三。下一条的日期 = 锚点 +
  /// `n × interval`，n 从锚点算起。
  ///
  /// **存的是完整时刻，不是本地零点**：带时刻的重复任务（每天 09:30）
  /// 要保住那个时刻；只精确到日的任务，锚点本来就落在本地零点上。
  ///
  /// **默认值 0 只是给 SQLite 用的**：给已有的表加一个非空列时它要求
  /// 有默认值，否则整条 `ALTER TABLE` 会被拒。0 换算出来是 1970 年，
  /// 一眼能看出是「没写过」，`RecurrenceRepository` 读到 0 时会退回用
  /// 规则的创建时间兜底。
  IntColumn get startsOn => integer().withDefault(const Constant(0))();

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

  /// 最多生成几条（**含第 1 条**）。`null` = 不限次数。
  ///
  /// 计数口径是「这个系列现在有几条任务」，所以删掉一条历史实例会让系列
  /// 少算一次、也就是多跑一次。这是刻意的取舍：与其维护一个会跟现实
  /// 走散的计数器，不如每次当场数一遍。
  IntColumn get endCount => integer().nullable()();

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
