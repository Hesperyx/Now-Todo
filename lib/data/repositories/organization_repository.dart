import 'package:drift/drift.dart';

import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';

/// 清单与标签。
///
/// 两者放在一个文件里，是因为它们在数据模型上是同一件事的两个投影：
/// 「把任务分堆」。分开写会重复一套 find-or-create + 计数聚合的代码。
/// 如果哪天其中一个长出独立行为（比如嵌套清单），再拆不迟。

/// 清单读写。
class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;

  /// 监听全部清单，带未完成任务数。
  Stream<List<TodoList>> watch() {
    return _db
        .customSelect(
          '''
SELECT
  l.id, l.name, l.color, l.is_built_in, l.sort_order, l.created_at, l.updated_at,
  (SELECT COUNT(*) FROM tasks t
    WHERE t.list_id = l.id AND t.status = ?) AS pending_count
FROM task_lists l
ORDER BY l.sort_order ASC, l.name COLLATE NOCASE ASC;
''',
          variables: <Variable<Object>>[
            Variable<int>(TaskStatus.pending.index),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.taskLists,
            _db.tasks,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows.map(_mapList).toList(growable: false),
        );
  }

  Future<String> create(String name, {int? color}) async {
    final String id = newId();
    final int now = nowUtcMillis();
    // 新清单排在最后：用户已经排好的顺序不该被一次「新建」打乱。
    final int maxOrder = await _maxSortOrder();
    await _db
        .into(_db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: id,
            name: name.trim(),
            color: Value(color),
            sortOrder: Value(maxOrder + 1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.taskLists)..where((t) => t.id.equals(id))).write(
      TaskListsCompanion(
        name: Value(name.trim()),
        updatedAt: Value(nowUtcMillis()),
      ),
    );
  }

  Future<void> setColor(String id, int? color) async {
    await (_db.update(_db.taskLists)..where((t) => t.id.equals(id))).write(
      TaskListsCompanion(color: Value(color), updatedAt: Value(nowUtcMillis())),
    );
  }

  /// 删除清单。
  ///
  /// **不删里面的任务**——数据库的 `ON DELETE SET NULL` 会把它们的
  /// `list_id` 置空，任务回到「未分类」。删一个清单就让几十条任务
  /// 凭空消失是最容易招骂的行为，不做。
  ///
  /// 内置清单会被拒绝，返回 `false`。
  Future<bool> delete(String id) async {
    final bool isBuiltIn = await _isBuiltIn(id);
    if (isBuiltIn) return false;
    await (_db.delete(_db.taskLists)..where((t) => t.id.equals(id))).go();
    return true;
  }

  Future<void> reorder(List<String> orderedIds) async {
    final int now = nowUtcMillis();
    await _db.transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.taskLists,
        )..where((t) => t.id.equals(orderedIds[i]))).write(
          TaskListsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<bool> _isBuiltIn(String id) async {
    final query = _db.selectOnly(_db.taskLists)
      ..addColumns(<Expression<Object>>[_db.taskLists.isBuiltIn])
      ..where(_db.taskLists.id.equals(id));
    final row = await query.getSingleOrNull();
    return row?.read(_db.taskLists.isBuiltIn) ?? false;
  }

  Future<int> _maxSortOrder() async {
    final Expression<int> maxExpr = _db.taskLists.sortOrder.max();
    final query = _db.selectOnly(_db.taskLists)
      ..addColumns(<Expression<Object>>[maxExpr]);
    final row = await query.getSingleOrNull();
    return row?.read(maxExpr) ?? 0;
  }

  static TodoList _mapList(QueryRow row) => TodoList(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    color: row.read<int?>('color'),
    isBuiltIn: row.read<bool>('is_built_in'),
    sortOrder: row.read<int>('sort_order'),
    createdAt: row.read<int>('created_at'),
    updatedAt: row.read<int>('updated_at'),
    pendingCount: row.read<int>('pending_count'),
  );
}

/// 标签读写。
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  /// 监听全部标签，带引用它的任务数。
  ///
  /// 计数包含已完成的任务：标签是归档用的，把它算成 0 会让人以为标签坏了。
  Stream<List<TodoTag>> watch() {
    return _db
        .customSelect(
          '''
SELECT
  g.id, g.name, g.color, g.created_at,
  (SELECT COUNT(*) FROM task_tags tt WHERE tt.tag_id = g.id) AS task_count
FROM tags g
ORDER BY g.name COLLATE NOCASE ASC;
''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.tags,
            _db.taskTags,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows.map(_mapTag).toList(growable: false),
        );
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(name: Value(name.trim())),
    );
  }

  Future<void> setColor(String id, int? color) async {
    await (_db.update(
      _db.tags,
    )..where((t) => t.id.equals(id))).write(TagsCompanion(color: Value(color)));
  }

  /// 删除标签。任务本身不受影响，只是少一个标记
  /// （`task_tags` 的关联行由外键级联删除）。
  Future<void> delete(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  static TodoTag _mapTag(QueryRow row) => TodoTag(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    color: row.read<int?>('color'),
    createdAt: row.read<int>('created_at'),
    taskCount: row.read<int>('task_count'),
  );
}
