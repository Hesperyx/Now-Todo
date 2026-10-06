import 'package:drift/drift.dart';

import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/models/task_query.dart';
import '../../core/recurrence/recurrence.dart';
import '../../core/recurrence/recurrence_rule.dart' as core;
import '../../core/utils/ids.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';
import 'recurrence_repository.dart';

/// 任务读写。
///
/// 界面层只跟这个类打交道，拿到的永远是 [TodoTask]，看不到 Drift 的
/// 生成类型。见 `docs/ARCHITECTURE.md` §3。
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  // ───────────────────────────── 读 ─────────────────────────────

  /// 监听符合条件的任务列表。
  ///
  /// 用一条手写 SQL 而不是 drift 的类型化查询，是因为列表页需要
  /// 「子任务完成进度」和「标签」这两个聚合值。用 drift 的 join 表达
  /// 会变成 group by + 多次查询合并，反而更难读；手写 SQL 里用相关
  /// 子查询一次算清楚，也能让 SQLite 走索引。
  ///
  /// [readsFrom] 必须把子查询涉及的表都列上，否则那些表变化时
  /// 这个 stream 不会重新发射——这是 drift 跟踪依赖的方式。
  Stream<List<TodoTask>> watch(TaskQuery query) {
    final _BuiltQuery built = _buildListQuery(query);
    return _db
        .customSelect(
          built.sql,
          variables: built.variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.tasks,
            _db.subtasks,
            _db.taskTags,
            _db.tags,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows.map(_mapTask).toList(growable: false),
        );
  }

  /// 按 id 取一条任务（含聚合字段）。不存在时返回 `null`。
  Future<TodoTask?> findById(String id) async {
    // 必须用 getSingleOrNull：getSingle 在零行时会抛 StateError，
    // 而「查询一个刚被删掉的 id」是完全正常的调用。
    final QueryRow? row = await _db
        .customSelect(
          '${_taskSelectColumns()} FROM tasks t WHERE t.id = ? LIMIT 1;',
          variables: <Variable<Object>>[Variable<String>(id)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.tasks,
            _db.subtasks,
            _db.taskTags,
            _db.tags,
          },
        )
        .getSingleOrNull();
    return row == null ? null : _mapTask(row);
  }

  /// 单条任务的实时视图。任务被删除时发射 `null`。
  ///
  /// 编辑页用它而不是 [findById]：在别处改了同一条任务（比如首页勾了完成），
  /// 编辑页要立刻反映出来，而不是拿着打开那一刻的旧数据回写。
  Stream<TodoTask?> watchSingle(String id) {
    return _db
        .customSelect(
          '${_taskSelectColumns()} FROM tasks t WHERE t.id = ? LIMIT 1;',
          variables: <Variable<Object>>[Variable<String>(id)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.tasks,
            _db.subtasks,
            _db.taskTags,
            _db.tags,
          },
        )
        .watchSingleOrNull()
        .map((QueryRow? row) => row == null ? null : _mapTask(row));
  }

  /// 未完成任务总数，用于清单角标之类的展示。
  Stream<int> watchPendingCount() {
    final Expression<bool> pending = _db.tasks.status.equalsValue(
      TaskStatus.pending,
    );
    final Expression<int> count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns(<Expression<Object>>[count])
      ..where(pending);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// 监听某个任务的子任务，按 [TodoSubtask.sortOrder] 升序。
  Stream<List<TodoSubtask>> watchSubtasks(String taskId) {
    final query = _db.select(_db.subtasks)
      ..where((t) => t.taskId.equals(taskId))
      ..orderBy(<OrderingTerm Function($SubtasksTable)>[
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch().map(
      (List<Subtask> rows) => rows.map(_mapSubtask).toList(growable: false),
    );
  }

  // ───────────────────────────── 写 ─────────────────────────────

  /// 新建任务，返回新 id。
  ///
  /// `title` 会去掉首尾空白；调用方应在此之前做非空校验
  /// （数据库也有 `min: 1` 的长度约束兜底）。
  ///
  /// [recurrenceRuleId] 由 `RecurrenceRepository` 先建好规则再传进来——
  /// 任务只记一个 id，规则的字段一个都不重复。
  Future<String> create({
    required String title,
    String? note,
    int? dueDate,
    bool dueDateHasTime = false,
    TaskPriority priority = TaskPriority.none,
    String? listId,
    String? recurrenceRuleId,
  }) async {
    final String id = newId();
    final int now = nowUtcMillis();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            title: title.trim(),
            note: Value(note),
            dueDate: Value(dueDate),
            dueDateHasTime: Value(dueDateHasTime),
            priority: Value(priority),
            status: const Value(TaskStatus.pending),
            listId: Value(listId),
            recurrenceRuleId: Value(recurrenceRuleId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// 覆盖写一条任务的「编辑页字段」：标题、备注、截止时间、优先级、清单、重复规则。
  ///
  /// 全量写而不是局部写：调用方是编辑页，它手上本来就有这几个字段的完整值。
  /// 局部更新的签名需要 `Value<T>`/`Value.absent()` 来表达「不改」，
  /// 那会把 drift 的包装类型漏进界面层，违反 `docs/ARCHITECTURE.md` §3。
  ///
  /// 完成状态不在这里改——它走 [setCompleted]，因为那还牵着 `completedAt`。
  Future<void> update(
    String id, {
    required String title,
    required String? note,
    required int? dueDate,
    required bool dueDateHasTime,
    required TaskPriority priority,
    required String? listId,
    required String? recurrenceRuleId,
  }) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(title.trim()),
        note: Value(note),
        dueDate: Value(dueDate),
        dueDateHasTime: Value(dueDateHasTime),
        priority: Value(priority),
        listId: Value(listId),
        recurrenceRuleId: Value(recurrenceRuleId),
        updatedAt: Value(nowUtcMillis()),
      ),
    );
  }

  /// 勾选 / 取消勾选。完成时记 [completedAt]，取消时清空它。
  ///
  /// 返回值是**这个系列新生成的那条任务的 id**，没有生成就是 `null`。
  /// 首页拿它弹一句「下一条：2026-10-12」，用户才知道重复真的在跑。
  ///
  /// 重复任务的做法是**完成后另起一条新任务**，不是把同一条的截止日期往后
  /// 推——后者会把「我昨天做过这件事」的记录抹掉（验收第 3 条：结束重复不该
  /// 删掉历史已完成实例）。
  ///
  /// 整个动作在一个事务里：先确认「原来确实没完成」再生成，否则连点两下
  /// 勾选框会生出两条。取消勾选不碰系列。
  Future<String?> setCompleted(String id, bool completed) async {
    final int now = nowUtcMillis();

    return _db.transaction<String?>(() async {
      final TodoTask? before = await findById(id);
      if (before == null) return null;

      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          status: Value(completed ? TaskStatus.completed : TaskStatus.pending),
          completedAt: Value(completed ? now : null),
          updatedAt: Value(now),
        ),
      );

      final String? ruleId = before.recurrenceRuleId;
      // 只有「从未完成变成完成」才推系列；取消勾选、或者本来就是完成态
      // （重复点击、界面重放）都不该生出下一条。
      if (!completed || before.status == TaskStatus.completed) return null;
      if (ruleId == null) return null;

      return _spawnNext(before, ruleId, now: now);
    });
  }

  /// 按重复规则算出下一条并落库，返回新任务 id。
  ///
  /// 规则行由这里自己查、自己解：仓储之间不互相调用是本项目的约定
  /// （`decodeRule` 是公开的顶层函数，就是为了让这条查询不必再抄一遍）。
  Future<String?> _spawnNext(
    TodoTask finished,
    String ruleId, {
    required int now,
  }) async {
    final RecurrenceRule? row = await (_db.select(
      _db.recurrenceRules,
    )..where((r) => r.id.equals(ruleId))).getSingleOrNull();
    // 规则没了（用户中途「结束重复」）就到此为止。剩下的实例各自独立。
    if (row == null) return null;

    final core.RecurrenceRule rule = decodeRule(row);
    final int seriesCount = await _countSeries(ruleId);

    final DateTime moment = fromUtcMillis(now);
    // 只精确到日的任务，新的一条也不该带上时刻：拿「现在」当界会把
    // 今天已经过掉的那次也判成逾期。
    final DateTime notBefore = finished.dueDateHasTime
        ? moment
        : DateTime(moment.year, moment.month, moment.day);

    // 只精确到日的实例要按「这一天结束了」来对齐节奏。拿当天零点去问
    // 「下一个不晚于它的日期」，规则里的时刻（比如每天 09:30）会让答案落回
    // 同一个日历日，于是每一次完成都生出同一天的下一条，系列原地踏步。
    final DateTime instanceDate = finished.dueDate == null
        ? rule.startsOn
        : _alignmentPoint(
            fromUtcMillis(finished.dueDate!),
            hasTime: finished.dueDateHasTime,
          );

    final DateTime? next = nextAfterCompletion(
      rule: rule,
      instanceDate: instanceDate,
      notBefore: notBefore,
      seriesCount: seriesCount,
    );
    if (next == null) return null;

    final String newTaskId = newId();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: newTaskId,
            title: finished.title,
            note: Value(finished.note),
            dueDate: Value(
              finished.dueDateHasTime ? next.utcMillis : dayOnlyMillis(next),
            ),
            dueDateHasTime: Value(finished.dueDateHasTime),
            priority: Value(finished.priority),
            status: const Value(TaskStatus.pending),
            listId: Value(finished.listId),
            recurrenceRuleId: Value(ruleId),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 标签跟着走：它描述的是「这是哪一类事」，而不是「这一次」。
    // 子任务不跟：那是这一条自己的清单，上一轮勾掉的东西带过来只会碍事。
    if (finished.tagNames.isNotEmpty) {
      await setTaskTags(newTaskId, finished.tagNames);
    }
    return newTaskId;
  }

  /// 拿一条实例去对齐系列节奏时，用哪个时刻。
  ///
  /// 带时刻的实例就是它自己；只到日的实例取「这一天 23:59:59.999」——它代表的
  /// 是整整一天，而不是零点那一瞬间。
  static DateTime _alignmentPoint(DateTime due, {required bool hasTime}) {
    if (hasTime) return due;
    return DateTime(
      due.year,
      due.month,
      due.day + 1,
    ).subtract(const Duration(milliseconds: 1));
  }

  /// 这个系列现在有几条任务。**含刚完成的那条**——计数口径是「已经生成过
  /// 几条」，不是「还剩几条」。删掉历史实例会让系列多跑一次，这是刻意的
  /// 取舍，理由写在[表定义][RecurrenceRules.endCount]里。
  Future<int> _countSeries(String ruleId) async {
    final Expression<int> count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns(<Expression<Object>>[count])
      ..where(_db.tasks.recurrenceRuleId.equals(ruleId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// 硬删除。子任务、标签关联、提醒会由外键 `ON DELETE CASCADE` 带走。
  ///
  /// 依赖的是**数据库**的级联，不是应用层的多步删除：这样即使某天有别的
  /// 代码路径删了任务，也不会留下孤儿行。
  Future<void> delete(String id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  /// 删除所有已完成的任务，返回删掉的条数。
  Future<int> deleteCompleted() {
    return (_db.delete(
      _db.tasks,
    )..where((t) => t.status.equalsValue(TaskStatus.completed))).go();
  }

  /// 把一条刚被删掉的任务原样放回去，用于「撤销删除」。
  ///
  /// 连 `id`、`createdAt`、`updatedAt` 一起还原——重新生成 id 会让
  /// 任何正在看这条任务的界面（编辑页、已打开的提醒）指向一个死引用。
  ///
  /// **能恢复的只有任务本身和它的标签。** 子任务和提醒在删除时已被
  /// 外键级联带走，这里补不回来。所以首页的撤销提示不写成
  /// 「已恢复全部内容」——那是谎话。
  ///
  /// 用 `InsertMode.insertOrIgnore`：万一 id 又存在了（极端情况，
  /// 比如撤销和导入撞在一起），宁可什么都不做，也不要覆盖。
  /// 先查一次再插，是因为 `insert` 的返回值在 `insertOrIgnore` 分支上
  /// 表示的是「影响行数」还是「rowid」取决于 drift 内部实现，
  /// 不值得为了省一条 `SELECT` 去赌它。
  Future<bool> restore(TodoTask task) async {
    if (await _exists(task.id)) return false;

    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion(
            id: Value(task.id),
            title: Value(task.title),
            note: Value(task.note),
            dueDate: Value(task.dueDate),
            dueDateHasTime: Value(task.dueDateHasTime),
            priority: Value(task.priority),
            status: Value(task.status),
            listId: Value(task.listId),
            recurrenceRuleId: Value(task.recurrenceRuleId),
            createdAt: Value(task.createdAt),
            updatedAt: Value(task.updatedAt),
            completedAt: Value(task.completedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    if (task.tagNames.isNotEmpty) {
      await setTaskTags(task.id, task.tagNames);
    }
    return true;
  }

  Future<bool> _exists(String id) async {
    final query = _db.selectOnly(_db.tasks)
      ..addColumns(<Expression<Object>>[_db.tasks.id])
      ..where(_db.tasks.id.equals(id))
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  // ─────────────────────────── 子任务 ───────────────────────────

  Future<String> addSubtask(String taskId, String title) async {
    final List<Subtask> existing = await (_db.select(
      _db.subtasks,
    )..where((t) => t.taskId.equals(taskId))).get();
    final String id = newId();
    await _db
        .into(_db.subtasks)
        .insert(
          SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: title.trim(),
            // 追加到末尾：新加的子任务排最后，不会打乱用户已经排好的顺序。
            sortOrder: Value(existing.length),
            createdAt: nowUtcMillis(),
          ),
        );
    return id;
  }

  Future<void> setSubtaskDone(String subtaskId, bool done) async {
    await (_db.update(_db.subtasks)..where((t) => t.id.equals(subtaskId)))
        .write(SubtasksCompanion(isDone: Value(done)));
  }

  Future<void> renameSubtask(String subtaskId, String title) async {
    await (_db.update(_db.subtasks)..where((t) => t.id.equals(subtaskId)))
        .write(SubtasksCompanion(title: Value(title.trim())));
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await (_db.delete(_db.subtasks)..where((t) => t.id.equals(subtaskId))).go();
  }

  /// 按给定顺序重排子任务的 `sort_order`，下标就是新的顺序。
  ///
  /// 只动传进来的这些 id。界面上拖拽时传的是整个列表，漏掉一条的话它会保持
  /// 原来的号数——比把它悄悄挪到末尾好，那种「我没碰它它却跑了」最难查。
  Future<void> reorderSubtasks(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await _db.transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.subtasks)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(SubtasksCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ───────────────────────────── 标签 ─────────────────────────────

  /// 用一组标签名**整体替换**某个任务的标签。
  ///
  /// 标签名不存在时自动创建。重名判断是**大小写敏感的精确匹配**，
  /// 与 `tags_name` 唯一索引的语义保持一致：`Work` 和 `work` 是两个标签。
  /// 空白、空串和重复项会被丢掉。删除 + 重建在同一个事务里，
  /// 所以中途失败不会留下「旧标签删了、新标签没建上」的中间态。
  Future<void> setTaskTags(String taskId, List<String> names) async {
    final List<String> cleaned = <String>[];
    for (final String raw in names) {
      final String name = raw.trim();
      if (name.isNotEmpty && !cleaned.contains(name)) cleaned.add(name);
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.taskTags,
      )..where((t) => t.taskId.equals(taskId))).go();
      for (final String name in cleaned) {
        final String tagId = await _ensureTag(name);
        await _db
            .into(_db.taskTags)
            .insert(
              TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId)),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// 取出已有标签 id，没有就建一个。
  Future<String> _ensureTag(String name) async {
    final Tag? existing =
        await (_db.select(_db.tags)
              ..where((t) => t.name.equals(name))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final String id = newId();
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(id: id, name: name, createdAt: nowUtcMillis()),
        );
    return id;
  }

  // ───────────────────────────── 内部 ─────────────────────────────

  /// `SELECT` 的列清单。抽出来是为了让 `watch` 与 `findById` 用同一份定义，
  /// 加字段时不会只改一处。
  static String _taskSelectColumns() {
    return '''
SELECT
  t.id                    AS id,
  t.title                 AS title,
  t.note                  AS note,
  t.due_date              AS due_date,
  t.due_date_has_time     AS due_date_has_time,
  t.priority              AS priority,
  t.status                AS status,
  t.list_id               AS list_id,
  t.recurrence_rule_id    AS recurrence_rule_id,
  t.created_at            AS created_at,
  t.updated_at            AS updated_at,
  t.completed_at          AS completed_at,
  (SELECT COUNT(*) FROM subtasks s WHERE s.task_id = t.id) AS subtask_total,
  (SELECT COUNT(*) FROM subtasks s WHERE s.task_id = t.id AND s.is_done = 1) AS subtask_done,
  (SELECT GROUP_CONCAT(g.name, char(31))
     FROM task_tags tt JOIN tags g ON g.id = tt.tag_id
    WHERE tt.task_id = t.id) AS tag_names
''';
  }

  /// 标签名的分隔符：ASCII `US`（0x1F）。
  ///
  /// 不用逗号，因为用户可以给标签起名叫「a,b」——那样一个标签会被
  /// 拆成两个显示。控制字符几乎不可能出现在用户输入里，
  /// 而且 SQLite 的 `char()` 能直接生成它。
  static const String _tagSeparator = '\u001f';

  static TodoTask _mapTask(QueryRow row) {
    final String? rawTags = row.read<String?>('tag_names');
    return TodoTask(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      note: row.read<String?>('note'),
      dueDate: row.read<int?>('due_date'),
      dueDateHasTime: row.read<bool>('due_date_has_time'),
      priority: _enumAt(TaskPriority.values, row.read<int>('priority')),
      status: _enumAt(TaskStatus.values, row.read<int>('status')),
      listId: row.read<String?>('list_id'),
      recurrenceRuleId: row.read<String?>('recurrence_rule_id'),
      createdAt: row.read<int>('created_at'),
      updatedAt: row.read<int>('updated_at'),
      completedAt: row.read<int?>('completed_at'),
      subtaskTotal: row.read<int>('subtask_total'),
      subtaskDone: row.read<int>('subtask_done'),
      tagNames: rawTags == null || rawTags.isEmpty
          ? const <String>[]
          : (rawTags.split(_tagSeparator)..sort()),
    );
  }

  static TodoSubtask _mapSubtask(Subtask row) => TodoSubtask(
    id: row.id,
    taskId: row.taskId,
    title: row.title,
    isDone: row.isDone,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
  );

  static _BuiltQuery _buildListQuery(TaskQuery query) {
    final List<String> clauses = <String>[];
    final List<Variable<Object>> variables = <Variable<Object>>[];
    final int now = nowUtcMillis();

    if (!query.showCompleted) {
      clauses.add('t.status = ?');
      variables.add(Variable<int>(TaskStatus.pending.index));
    }

    if (query.dueTodayOnly) {
      // 左闭右开，见 lib/core/utils/time.dart 的说明。
      clauses.add('t.due_date >= ? AND t.due_date < ?');
      variables.add(Variable<int>(startOfLocalDayMillis(fromUtcMillis(now))));
      variables.add(Variable<int>(endOfLocalDayMillis(fromUtcMillis(now))));
    }

    if (query.overdueOnly) {
      // 已完成的「逾期」不算逾期，所以这里再钉一次状态，
      // 不依赖上面的 showCompleted 分支。
      clauses.add('t.due_date IS NOT NULL AND t.due_date < ? AND t.status = ?');
      variables.add(Variable<int>(now));
      variables.add(Variable<int>(TaskStatus.pending.index));
    }

    final String? listId = query.listId;
    if (listId != null) {
      clauses.add('t.list_id = ?');
      variables.add(Variable<String>(listId));
    }

    final String? tagName = query.tagName?.trim();
    if (tagName != null && tagName.isNotEmpty) {
      clauses.add(
        'EXISTS (SELECT 1 FROM task_tags tt JOIN tags g ON g.id = tt.tag_id '
        'WHERE tt.task_id = t.id AND g.name = ? COLLATE NOCASE)',
      );
      variables.add(Variable<String>(tagName));
    }

    final String? search = query.normalizedSearch;
    if (search != null) {
      final String pattern = '%${_escapeLike(search)}%';
      clauses.add(
        r"(t.title LIKE ? ESCAPE '\' OR IFNULL(t.note, '') LIKE ? ESCAPE '\')",
      );
      variables
        ..add(Variable<String>(pattern))
        ..add(Variable<String>(pattern));
    }

    if (query.priorities.isNotEmpty) {
      final List<TaskPriority> sorted = query.priorities.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      final String placeholders = List<String>.filled(
        sorted.length,
        '?',
      ).join(', ');
      clauses.add('t.priority IN ($placeholders)');
      for (final TaskPriority p in sorted) {
        variables.add(Variable<int>(p.index));
      }
    }

    final String where = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';

    return _BuiltQuery(
      '${_taskSelectColumns()} FROM tasks t $where ${_orderBy(query.sort)};',
      variables,
    );
  }

  static String _orderBy(TaskSort sort) => switch (sort) {
    // `(t.due_date IS NULL)` 得到 0/1，把「有截止日期」的排在前面。
    // 没有截止日期的任务按创建时间倒序，让新加的浮在上面。
    TaskSort.dueDate =>
      'ORDER BY (t.due_date IS NULL) ASC, t.due_date ASC, t.created_at DESC',
    TaskSort.priority =>
      'ORDER BY t.priority DESC, (t.due_date IS NULL) ASC, t.due_date ASC, t.created_at DESC',
    TaskSort.createdAt => 'ORDER BY t.created_at DESC',
    TaskSort.title => 'ORDER BY t.title COLLATE NOCASE ASC',
  };

  /// 转义 `LIKE` 的通配符。
  ///
  /// 不转义的话，用户搜 `50%` 会匹配到一堆无关的任务，
  /// 搜 `_` 会匹配到所有单字符标题。
  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// 把数据库里的整数还原成枚举。
  ///
  /// 索引越界时**回退到第一个值**而不是抛异常：数据库里出现未知整数
  /// 通常意味着用户装了更新版本又降级回来，这时候让界面能打开、
  /// 比直接崩掉更有用。日志里会留下痕迹（见 §10）。
  static T _enumAt<T>(List<T> values, int index) {
    if (index < 0 || index >= values.length) return values.first;
    return values[index];
  }
}

/// 拼好的 SQL 与它的变量。
class _BuiltQuery {
  const _BuiltQuery(this.sql, this.variables);

  final String sql;
  final List<Variable<Object>> variables;
}
