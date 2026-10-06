import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../core/backup/backup_codec.dart';
import '../../core/backup/backup_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';
import 'settings_repository.dart';

/// 怎么把文件里的数据并进本地。
enum ImportMode {
  /// 合并：按 `id` 找本地那一行，文件里的记录**更新**才覆盖；本地没有的补进来。
  ///
  /// 「更新」的判据是各自的时间戳（`updatedAt`；没有它的表用 `createdAt`，
  /// 专注记录用 `startedAt`，见 [_fileWins]）。时间戳相等时保留本地——
  /// 这样把同一份文件导入两次，第二次什么都不会变。
  merge,

  /// 覆盖：先清空八张业务表，再整体写入。设置也会被文件里的替换。
  overwrite,
}

/// 一次导入的结果。
class ImportOutcome {
  const ImportOutcome({
    required this.mode,
    required this.counts,
    required this.skipped,
  });

  final ImportMode mode;

  /// 每张表实际写进去（新增或覆盖）的行数。
  final Map<String, int> counts;

  /// 每张表被跳过的行数：合并模式下本地那份不更旧，另外还有「导出时还没结束
  /// 的专注记录」（见 [BackupRepository.importData]）。
  final Map<String, int> skipped;

  /// 一句话结果，直接弹给用户。
  String get summary {
    final StringBuffer buffer = StringBuffer(
      mode == ImportMode.overwrite ? '覆盖导入完成。' : '合并导入完成。',
    );
    final String written = _describe(counts);
    buffer.write(written.isEmpty ? '没有需要写入的内容。' : '写入了$written。');
    final String left = _describe(skipped);
    if (left.isNotEmpty) buffer.write('跳过了$left。');
    return buffer.toString();
  }

  static String _describe(Map<String, int> counts) {
    final List<String> parts = <String>[];
    for (final MapEntry<String, String> unit in _unitNames.entries) {
      final int count = counts[unit.key] ?? 0;
      if (count > 0) parts.add('$count${unit.value}');
    }
    return parts.join('、');
  }

  static const Map<String, String> _unitNames = <String, String>{
    'taskLists': '个清单',
    'tags': '个标签',
    'tasks': '条任务',
    'taskTags': '处标签关系',
    'subtasks': '条子任务',
    'reminders': '条提醒',
    'recurrenceRules': '条重复规则',
    'focusSessions': '段专注记录',
    'settings': '项设置',
  };
}

/// 全库导入导出。
///
/// 两边写在同一个类里，是因为字段清单必须一起改：只改一边的表现是
/// 「导出的东西导不回来」，而那种错误往往要等真的备份过一次之后才会发现。
class BackupRepository {
  BackupRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  /// 导出全库。
  ///
  /// 每张表都按固定顺序取（清单按顺序位、任务按创建时间、提醒按触发时刻……）：
  /// 顺序固定的文件才能用眼睛看、才能 diff——同一份数据导出两次，除了
  /// `exportedAt` 之外应当逐行相同。
  Future<BackupData> export({required String appVersion}) async {
    final List<TaskList> lists =
        await (_db.select(_db.taskLists)
              ..orderBy(<OrderingTerm Function($TaskListsTable)>[
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<Tag> tags =
        await (_db.select(_db.tags)
              ..orderBy(<OrderingTerm Function($TagsTable)>[
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
    final List<RecurrenceRule> rules =
        await (_db.select(_db.recurrenceRules)
              ..orderBy(<OrderingTerm Function($RecurrenceRulesTable)>[
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<Task> tasks =
        await (_db.select(_db.tasks)
              ..orderBy(<OrderingTerm Function($TasksTable)>[
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<Subtask> subtasks =
        await (_db.select(_db.subtasks)
              ..orderBy(<OrderingTerm Function($SubtasksTable)>[
                (t) => OrderingTerm.asc(t.taskId),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    final List<Reminder> reminders =
        await (_db.select(_db.reminders)
              ..orderBy(<OrderingTerm Function($RemindersTable)>[
                (t) => OrderingTerm.asc(t.remindAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<TaskTag> taskTags =
        await (_db.select(_db.taskTags)
              ..orderBy(<OrderingTerm Function($TaskTagsTable)>[
                (t) => OrderingTerm.asc(t.taskId),
                (t) => OrderingTerm.asc(t.tagId),
              ]))
            .get();
    final List<FocusSession> sessions =
        await (_db.select(_db.focusSessions)
              ..orderBy(<OrderingTerm Function($FocusSessionsTable)>[
                (t) => OrderingTerm.asc(t.startedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return BackupData(
      exportedAt: nowUtcMillis(),
      app: BackupAppInfo(
        name: AppConstants.databaseName,
        version: appVersion,
        schemaVersion: _db.schemaVersion,
      ),
      taskLists: <BackupListRow>[
        for (final TaskList row in lists)
          BackupListRow(
            id: row.id,
            name: row.name,
            color: row.color,
            isBuiltIn: row.isBuiltIn,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
      ],
      tags: <BackupTagRow>[
        for (final Tag row in tags)
          BackupTagRow(
            id: row.id,
            name: row.name,
            color: row.color,
            createdAt: row.createdAt,
          ),
      ],
      tasks: <BackupTaskRow>[
        for (final Task row in tasks)
          BackupTaskRow(
            id: row.id,
            title: row.title,
            note: row.note,
            dueDate: row.dueDate,
            dueDateHasTime: row.dueDateHasTime,
            priority: row.priority.index,
            status: row.status.index,
            listId: row.listId,
            recurrenceRuleId: row.recurrenceRuleId,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            completedAt: row.completedAt,
            estimatedPomodoros: row.estimatedPomodoros,
          ),
      ],
      taskTags: <BackupTaskTagRow>[
        for (final TaskTag row in taskTags)
          BackupTaskTagRow(taskId: row.taskId, tagId: row.tagId),
      ],
      subtasks: <BackupSubtaskRow>[
        for (final Subtask row in subtasks)
          BackupSubtaskRow(
            id: row.id,
            taskId: row.taskId,
            title: row.title,
            isDone: row.isDone,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
          ),
      ],
      reminders: <BackupReminderRow>[
        for (final Reminder row in reminders)
          BackupReminderRow(
            id: row.id,
            taskId: row.taskId,
            remindAt: row.remindAt,
            repeatType: row.repeatType.index,
            enabled: row.enabled,
            createdAt: row.createdAt,
          ),
      ],
      recurrenceRules: <BackupRecurrenceRow>[
        for (final RecurrenceRule row in rules)
          BackupRecurrenceRow(
            id: row.id,
            frequency: row.frequency.index,
            interval: row.interval,
            startsOn: row.startsOn,
            byWeekday: row.byWeekday,
            byMonthDay: row.byMonthDay,
            endDate: row.endDate,
            endCount: row.endCount,
            createdAt: row.createdAt,
          ),
      ],
      focusSessions: <BackupFocusSessionRow>[
        for (final FocusSession row in sessions)
          BackupFocusSessionRow(
            id: row.id,
            taskId: row.taskId,
            startedAt: row.startedAt,
            endedAt: row.endedAt,
            pausedMillis: row.pausedMillis,
            pausedAt: row.pausedAt,
            plannedSeconds: row.plannedSeconds,
            actualSeconds: row.actualSeconds,
            kind: row.kind.index,
            timerMode: row.timerMode.index,
            logicalDate: row.logicalDate,
            completed: row.completed,
            note: row.note,
          ),
      ],
      settings: await _settings.load(),
    );
  }

  /// 把一份备份写进本地库。
  ///
  /// 整个过程在**一个事务**里：中途任何一条写不进去（比如文件里有一条空标题，
  /// 长度约束在数据库那边），整批回滚，库保持在导入前的样子。宁可让用户看到
  /// 「导入失败」，也不要让他事后才发现少了三分之一的数据。
  ///
  /// 两处刻意的不对称：
  /// - `endedAt` 为空的专注记录会被跳过。一段还没结束的会话是**那台设备上的
  ///   当前状态**，不是历史；搬过来会凭空多出一段「正在计时」，同一时刻有两条
  ///   在跑的会话还会让「当前会话」那个查询直接抛错。
  /// - 合并模式不动本机设置（除非本机设置还是出厂值）：导入别人的备份不该
  ///   悄悄把主题、专注时长换掉。要连设置一起搬，就用覆盖导入。
  ///
  /// 写完会补一次 `ensureInitialized()`：覆盖模式清掉了内置的收件箱清单，
  /// 而「新建任务默认进哪个清单」依赖它存在。
  Future<ImportOutcome> importData(
    BackupData data, {
    required ImportMode mode,
  }) async {
    // 文件是外面来的。即使调用方已经解过一遍，这里再确认一次结构与引用：
    // `BackupData` 是可以手搓出来的，写到一半才发现引用悬空就得整批回滚。
    validateBackup(data);

    final Map<String, int> counts = <String, int>{};
    final Map<String, int> skipped = <String, int>{};
    final bool overwrite = mode == ImportMode.overwrite;

    await _db.transaction(() async {
      if (overwrite) await _clearAll();

      await _writeLists(
        data.taskLists,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeTags(
        data.tags,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      // 标签落库之后才算这张映射表：合并模式下文件里的标签 id 可能和本地对不上
      // （同名不同 id），引用它的标签关系得跟着改（理由见 _tagIdRemap）。
      // 覆盖模式本地已经清空，文件里的 id 就是本地的 id，不需要映射。
      final Map<String, String> tagIds = overwrite
          ? <String, String>{}
          : await _tagIdRemap(data.tags);
      await _writeRules(
        data.recurrenceRules,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeTasks(
        data.tasks,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeSubtasks(
        data.subtasks,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeReminders(
        data.reminders,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeTaskTags(
        data.taskTags,
        tagIds: tagIds,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );
      await _writeSessions(
        data.focusSessions,
        counts: counts,
        skipped: skipped,
      );
      await _writeSettings(
        data.settings,
        merge: !overwrite,
        counts: counts,
        skipped: skipped,
      );

      await _db.ensureInitialized();
    });

    return ImportOutcome(mode: mode, counts: counts, skipped: skipped);
  }

  // ─────────────────────────── 覆盖：清空 ───────────────────────────

  /// 反着外键的顺序删：先扔引用别人的，再扔被引用的。
  ///
  /// `app_settings` 那一行不动——它是单行表，后面的步骤直接覆写它。
  Future<void> _clearAll() async {
    await _db.delete(_db.taskTags).go();
    await _db.delete(_db.subtasks).go();
    await _db.delete(_db.reminders).go();
    await _db.delete(_db.focusSessions).go();
    await _db.delete(_db.tasks).go();
    await _db.delete(_db.recurrenceRules).go();
    await _db.delete(_db.tags).go();
    await _db.delete(_db.taskLists).go();
  }

  // ─────────────────────────── 合并：逐表落库 ───────────────────────────

  Future<void> _writeLists(
    List<BackupListRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, TaskList> local = _byId(
      await _db.select(_db.taskLists).get(),
      (TaskList row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupListRow row in rows) {
      final TaskList? existing = local[row.id];
      if (merge &&
          existing != null &&
          !_fileWins(existing.updatedAt, row.updatedAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.taskLists)
          .insertOnConflictUpdate(
            TaskListsCompanion(
              id: Value<String>(row.id),
              name: Value<String>(row.name),
              color: Value<int?>(row.color),
              isBuiltIn: Value<bool>(row.isBuiltIn),
              sortOrder: Value<int>(row.sortOrder),
              createdAt: Value<int>(row.createdAt),
              updatedAt: Value<int>(row.updatedAt),
            ),
          );
      written++;
    }
    counts['taskLists'] = written;
    if (kept > 0) skipped['taskLists'] = kept;
  }

  Future<void> _writeTags(
    List<BackupTagRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final List<Tag> local = await _db.select(_db.tags).get();
    final Map<String, Tag> byId = _byId(local, (Tag row) => row.id);
    final Set<String> names = <String>{for (final Tag row in local) row.name};

    int written = 0;
    int kept = 0;
    for (final BackupTagRow row in rows) {
      final Tag? existing = byId[row.id];
      // 本地已经有同名标签（id 不同）：库上 `tags.name` 是唯一索引，硬插会撞索引
      // 让整个事务回滚。用户眼里「工作」就是同一个标签，所以按名字认亲，本地的为准。
      if (merge && existing == null && names.contains(row.name)) {
        kept++;
        continue;
      }
      if (merge &&
          existing != null &&
          !_fileWins(existing.createdAt, row.createdAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.tags)
          .insertOnConflictUpdate(
            TagsCompanion(
              id: Value<String>(row.id),
              name: Value<String>(row.name),
              color: Value<int?>(row.color),
              createdAt: Value<int>(row.createdAt),
            ),
          );
      written++;
    }
    counts['tags'] = written;
    if (kept > 0) skipped['tags'] = kept;
  }

  Future<void> _writeRules(
    List<BackupRecurrenceRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, RecurrenceRule> local = _byId(
      await _db.select(_db.recurrenceRules).get(),
      (RecurrenceRule row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupRecurrenceRow row in rows) {
      final RecurrenceRule? existing = local[row.id];
      if (merge &&
          existing != null &&
          !_fileWins(existing.createdAt, row.createdAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.recurrenceRules)
          .insertOnConflictUpdate(
            RecurrenceRulesCompanion(
              id: Value<String>(row.id),
              frequency: Value<RecurrenceFrequency>(
                RecurrenceFrequency.values[row.frequency],
              ),
              interval: Value<int>(row.interval),
              startsOn: Value<int>(row.startsOn),
              byWeekday: Value<String?>(row.byWeekday),
              byMonthDay: Value<String?>(row.byMonthDay),
              endDate: Value<int?>(row.endDate),
              endCount: Value<int?>(row.endCount),
              createdAt: Value<int>(row.createdAt),
            ),
          );
      written++;
    }
    counts['recurrenceRules'] = written;
    if (kept > 0) skipped['recurrenceRules'] = kept;
  }

  Future<void> _writeTasks(
    List<BackupTaskRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, Task> local = _byId(
      await _db.select(_db.tasks).get(),
      (Task row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupTaskRow row in rows) {
      final Task? existing = local[row.id];
      if (merge &&
          existing != null &&
          !_fileWins(existing.updatedAt, row.updatedAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.tasks)
          .insertOnConflictUpdate(
            TasksCompanion(
              id: Value<String>(row.id),
              title: Value<String>(row.title),
              note: Value<String?>(row.note),
              dueDate: Value<int?>(row.dueDate),
              dueDateHasTime: Value<bool>(row.dueDateHasTime),
              priority: Value<TaskPriority>(TaskPriority.values[row.priority]),
              status: Value<TaskStatus>(TaskStatus.values[row.status]),
              listId: Value<String?>(row.listId),
              recurrenceRuleId: Value<String?>(row.recurrenceRuleId),
              createdAt: Value<int>(row.createdAt),
              updatedAt: Value<int>(row.updatedAt),
              completedAt: Value<int?>(row.completedAt),
              estimatedPomodoros: Value<int?>(row.estimatedPomodoros),
            ),
          );
      written++;
    }
    counts['tasks'] = written;
    if (kept > 0) skipped['tasks'] = kept;
  }

  Future<void> _writeSubtasks(
    List<BackupSubtaskRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, Subtask> local = _byId(
      await _db.select(_db.subtasks).get(),
      (Subtask row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupSubtaskRow row in rows) {
      final Subtask? existing = local[row.id];
      if (merge &&
          existing != null &&
          !_fileWins(existing.createdAt, row.createdAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.subtasks)
          .insertOnConflictUpdate(
            SubtasksCompanion(
              id: Value<String>(row.id),
              taskId: Value<String>(row.taskId),
              title: Value<String>(row.title),
              isDone: Value<bool>(row.isDone),
              sortOrder: Value<int>(row.sortOrder),
              createdAt: Value<int>(row.createdAt),
            ),
          );
      written++;
    }
    counts['subtasks'] = written;
    if (kept > 0) skipped['subtasks'] = kept;
  }

  Future<void> _writeReminders(
    List<BackupReminderRow> rows, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, Reminder> local = _byId(
      await _db.select(_db.reminders).get(),
      (Reminder row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupReminderRow row in rows) {
      final Reminder? existing = local[row.id];
      if (merge &&
          existing != null &&
          !_fileWins(existing.createdAt, row.createdAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.reminders)
          .insertOnConflictUpdate(
            RemindersCompanion(
              id: Value<String>(row.id),
              taskId: Value<String>(row.taskId),
              remindAt: Value<int>(row.remindAt),
              repeatType: Value<ReminderRepeatType>(
                ReminderRepeatType.values[row.repeatType],
              ),
              enabled: Value<bool>(row.enabled),
              createdAt: Value<int>(row.createdAt),
            ),
          );
      written++;
    }
    counts['reminders'] = written;
    if (kept > 0) skipped['reminders'] = kept;
  }

  /// 标签关系没有时间戳，合并时只有「有」和「没有」两种状态。
  ///
  /// 另外要过一道去重：按名字认亲之后，文件里两个不同 id 的同名标签会落到同一个
  /// 本地标签上，两条关系可能变成同一对——复合主键插第二次会抛。
  Future<void> _writeTaskTags(
    List<BackupTaskTagRow> rows, {
    required Map<String, String> tagIds,
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Set<String> local = <String>{
      for (final TaskTag row in await _db.select(_db.taskTags).get())
        _pairOf(row.taskId, row.tagId),
    };
    final Set<String> seen = <String>{};

    int written = 0;
    int kept = 0;
    for (final BackupTaskTagRow row in rows) {
      final String taskId = row.taskId;
      final String tagId = tagIds[row.tagId] ?? row.tagId;
      final String pair = _pairOf(taskId, tagId);
      if (!seen.add(pair)) {
        kept++;
        continue;
      }
      if (merge && local.contains(pair)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.taskTags)
          .insertOnConflictUpdate(
            TaskTagsCompanion(
              taskId: Value<String>(taskId),
              tagId: Value<String>(tagId),
            ),
          );
      written++;
    }
    counts['taskTags'] = written;
    if (kept > 0) skipped['taskTags'] = kept;
  }

  /// 文件里的标签 id → 本地那个标签的 id。
  ///
  /// 只在合并模式用：覆盖模式先把本地清空了，没有「已有」这回事，映射表是空的。
  ///
  /// 两种关系都会进这张表：id 本来就一样的（原样传下去），以及 id 不同但
  /// **名字一样**的——后者在 [_writeTags] 里被认成了「本地已有」，没有插进去，
  /// 可引用了它的标签关系还留在文件里；不映射过来，那些关系就会指着一个不存在的
  /// 标签，外键直接拒绝，整个导入回滚。
  Future<Map<String, String>> _tagIdRemap(List<BackupTagRow> rows) async {
    final List<Tag> local = await _db.select(_db.tags).get();
    final Set<String> ids = <String>{for (final Tag row in local) row.id};
    final Map<String, Tag> byName = <String, Tag>{
      for (final Tag row in local) row.name: row,
    };
    final Map<String, String> remap = <String, String>{};
    for (final BackupTagRow row in rows) {
      if (ids.contains(row.id)) {
        remap[row.id] = row.id;
        continue;
      }
      final Tag? sameName = byName[row.name];
      if (sameName != null) remap[row.id] = sameName.id;
    }
    return remap;
  }

  Future<void> _writeSessions(
    List<BackupFocusSessionRow> rows, {
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    final Map<String, FocusSession> local = _byId(
      await _db.select(_db.focusSessions).get(),
      (FocusSession row) => row.id,
    );
    int written = 0;
    int kept = 0;
    for (final BackupFocusSessionRow row in rows) {
      // 还没结束的会话属于设备上的当前状态，不搬（见 importData 的说明）。
      if (row.endedAt == null) {
        kept++;
        continue;
      }
      final FocusSession? existing = local[row.id];
      // 这张表没有 createdAt/updatedAt，用开始时刻当新旧判据：一段会话的身份就是
      // 「什么时候开始的」，改了它等于换了一段会话。
      if (existing != null && !_fileWins(existing.startedAt, row.startedAt)) {
        kept++;
        continue;
      }
      await _db
          .into(_db.focusSessions)
          .insertOnConflictUpdate(
            FocusSessionsCompanion(
              id: Value<String>(row.id),
              taskId: Value<String?>(row.taskId),
              startedAt: Value<int>(row.startedAt),
              endedAt: Value<int?>(row.endedAt),
              pausedMillis: Value<int>(row.pausedMillis),
              pausedAt: Value<int?>(row.pausedAt),
              plannedSeconds: Value<int?>(row.plannedSeconds),
              actualSeconds: Value<int>(row.actualSeconds),
              kind: Value<FocusSessionKind>(FocusSessionKind.values[row.kind]),
              timerMode: Value<FocusTimerMode>(
                FocusTimerMode.values[row.timerMode],
              ),
              logicalDate: Value<int>(row.logicalDate),
              completed: Value<bool>(row.completed),
              note: Value<String?>(row.note),
            ),
          );
      written++;
    }
    counts['focusSessions'] = written;
    if (kept > 0) skipped['focusSessions'] = kept;
  }

  Future<void> _writeSettings(
    AppPreferences preferences, {
    required bool merge,
    required Map<String, int> counts,
    required Map<String, int> skipped,
  }) async {
    if (merge && !(await _settings.load()).isDefault) {
      skipped['settings'] = 1;
      return;
    }
    await _settings.update(
      themeMode: preferences.themeMode,
      defaultView: preferences.defaultView,
      notificationsEnabled: preferences.notificationsEnabled,
      strongReminders: preferences.strongReminders,
      focusMinutes: preferences.focusMinutes,
      shortBreakMinutes: preferences.shortBreakMinutes,
      longBreakMinutes: preferences.longBreakMinutes,
      roundsBeforeLongBreak: preferences.roundsBeforeLongBreak,
      autoStartNext: preferences.autoStartNext,
      defaultTimerMode: preferences.defaultTimerMode,
      midnightMode: preferences.midnightMode,
      midnightEndHour: preferences.midnightEndHour,
    );
    counts['settings'] = 1;
  }

  /// 文件里的那一行要不要覆盖本地同名的那一行。
  ///
  /// 判据是时间戳：文件里**严格更新**才覆盖。相等时保留本地——「把同一份文件
  /// 导入两次，第二次什么都不改」比「猜哪边更对」重要。
  static bool _fileWins(int? localStamp, int? fileStamp) =>
      localStamp == null || (fileStamp != null && fileStamp > localStamp);

  static Map<String, T> _byId<T>(List<T> rows, String Function(T row) idOf) =>
      <String, T>{for (final T row in rows) idOf(row): row};

  static String _pairOf(String taskId, String tagId) => '$taskId\u0000$tagId';
}
