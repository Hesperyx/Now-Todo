import 'package:drift/drift.dart';

import 'tasks.dart';

/// 标签。一个任务可以有多个标签，一个标签也可以挂在多个任务上。
@TableIndex(name: 'tags_name', columns: {#name}, unique: true)
class Tags extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text()();

  /// 标签名。**唯一**——同名标签是用户的输入失误，不是两种东西。
  /// 新建时若已存在同名标签，复用已有的那条（大小写不敏感）。
  TextColumn get name => text().withLength(min: 1, max: 50)();

  IntColumn get color => integer().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务 ↔ 标签 的多对多关系。
///
/// 用**复合主键**而不是自增 id：`(taskId, tagId)` 天然唯一，
/// 数据库层面就挡住了「同一个标签贴两次」。
@TableIndex(name: 'task_tags_tag_id', columns: {#tagId})
class TaskTags extends Table {
  @override
  String get tableName => 'task_tags';

  /// 任务删除时连带删除关联行。
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// 标签删除时连带删除关联行。
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}
