import 'package:drift/drift.dart';

import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/notifications/reminder_plan.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';

/// 任务提醒读写。
///
/// 跟其它仓储一样，界面层只看到 [TodoReminder] 与 [ReminderSource]，
/// 看不到 Drift 的生成类型。
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  // ───────────────────────────── 读 ─────────────────────────────

  /// 监听某个任务的提醒，按触发时刻升序。
  Stream<List<TodoReminder>> watchForTask(String taskId) {
    return (_db.select(_db.reminders)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.asc(t.remindAt)]))
        .watch()
        .map((List<Reminder> rows) => rows.map(_map).toList(growable: false));
  }

  /// 一次性的读，给导入导出和测试用。
  Future<List<TodoReminder>> listForTask(String taskId) async {
    final List<Reminder> rows =
        await (_db.select(_db.reminders)
              ..where((t) => t.taskId.equals(taskId))
              ..orderBy([(t) => OrderingTerm.asc(t.remindAt)]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  /// 监听**全部**提醒，并带上排程需要的任务上下文。
  ///
  /// 这是 `ReminderScheduler` 唯一的数据入口。之所以连任务一起读，是因为
  /// 「任务被改名」「任务被勾完成」「任务被删掉」都会改变排程结果，
  /// 让它们也触发这个 stream 重新发射，才能保证计划永远和库一致。
  ///
  /// 用 `innerJoin` 而不是 `leftOuterJoin`：外键是 `ON DELETE CASCADE`，
  /// 任务没了提醒也会没，不存在孤儿行。
  Stream<List<ReminderSource>> watchSources() {
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db
        .select(_db.reminders)
        .join(<Join<HasResultSet, dynamic>>[
          innerJoin(_db.tasks, _db.tasks.id.equalsExp(_db.reminders.taskId)),
        ]);
    query.orderBy(<OrderingTerm>[OrderingTerm.asc(_db.reminders.remindAt)]);
    return query.watch().map(
      (List<TypedResult> rows) => rows
          .map((TypedResult row) {
            final Reminder reminder = row.readTable(_db.reminders);
            final Task task = row.readTable(_db.tasks);
            return ReminderSource(
              id: reminder.id,
              taskId: reminder.taskId,
              taskTitle: task.title,
              taskCompleted: task.status == TaskStatus.completed,
              remindAt: reminder.remindAt,
              repeatType: reminder.repeatType,
              enabled: reminder.enabled,
            );
          })
          .toList(growable: false),
    );
  }

  // ───────────────────────────── 写 ─────────────────────────────

  /// 新增一条提醒，返回新 id。一个任务可以有多条提醒。
  Future<String> add({
    required String taskId,
    required int remindAt,
    ReminderRepeatType repeatType = ReminderRepeatType.once,
  }) async {
    final String id = newId();
    await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: id,
            taskId: taskId,
            remindAt: remindAt,
            repeatType: Value<ReminderRepeatType>(repeatType),
            createdAt: nowUtcMillis(),
          ),
        );
    return id;
  }

  /// 只改传进来的字段。未传的一律不动。
  Future<void> update(
    String id, {
    int? remindAt,
    ReminderRepeatType? repeatType,
    bool? enabled,
  }) async {
    await (_db.update(_db.reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(
        remindAt: remindAt == null ? const Value.absent() : Value(remindAt),
        repeatType: repeatType == null
            ? const Value.absent()
            : Value<ReminderRepeatType>(repeatType),
        enabled: enabled == null ? const Value.absent() : Value(enabled),
      ),
    );
  }

  /// 硬删除。排好的系统通知不在这里撤——换了时间或删掉记录之后，
  /// `ReminderScheduler` 会收到新的快照并把不该响的撤掉。
  Future<void> delete(String id) async {
    await (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();
  }

  static TodoReminder _map(Reminder row) => TodoReminder(
    id: row.id,
    taskId: row.taskId,
    remindAt: row.remindAt,
    repeatType: row.repeatType,
    enabled: row.enabled,
    createdAt: row.createdAt,
  );
}
