import 'package:drift/drift.dart';

/// 清单。
///
/// 用户用它把任务分到不同场景（工作 / 生活 / 购物）。首版内置一个
/// 「收件箱」，未指定清单的任务都落在那里——但**不强制**用户使用清单，
/// 手工建的任务 `listId` 允许为空。
@TableIndex(name: 'task_lists_sort_order', columns: {#sortOrder})
class TaskLists extends Table {
  @override
  String get tableName => 'task_lists';

  /// 客户端生成的 UUID。见 `lib/core/utils/ids.dart`。
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// ARGB 颜色值。`null` 表示「跟随主题」，不用颜色区分。
  ///
  /// 存 `int` 而不是十六进制字符串：省空间，并且能直接在 Dart 侧
  /// 交给 `Color(...)`，不用来回解析。
  IntColumn get color => integer().nullable()();

  /// 是否内置清单。内置清单不允许删除，只允许改名和换色。
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// 排序权重，小的排前面。允许重复，重复时按名称兜底排序。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
