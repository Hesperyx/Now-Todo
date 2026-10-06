import 'package:drift/drift.dart';

import 'tasks.dart';

/// 子任务。
///
/// 刻意做成**一层**：子任务之下不再有子任务。
/// 多层嵌套会让「完成父任务时子任务怎么办」这类问题无限膨胀，
/// 而 PRD 首版要的只是一个可勾选的清单。
@TableIndex(name: 'subtasks_task_id', columns: {#taskId})
@TableIndex(name: 'subtasks_task_sort', columns: {#taskId, #sortOrder})
class Subtasks extends Table {
  @override
  String get tableName => 'subtasks';

  TextColumn get id => text()();

  /// 所属任务。任务删除时连带删除子任务。
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
