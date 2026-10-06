// 导入导出落在库上的那一半：什么时候覆盖、什么时候保留、失败怎么收场。
//
// 编解码那半边在 `test/core/backup/backup_codec_test.dart`；这里只关心一件事——
// 库最终长成什么样。几处刻意造出来的「库才会拦」的错误（比如标题是空串）是因为
// codec 只管类型与引用，长度约束归数据库，撞上必须整体回滚而不是半成功。

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/backup/backup_codec.dart';
import 'package:now_todo/core/backup/backup_model.dart';
import 'package:now_todo/core/constants/app_constants.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';
import 'package:now_todo/core/utils/time.dart';
// 领域里的 `RecurrenceRule` 与 drift 生成的数据类同名，这里给数据库文件加前缀，
// 让不带前缀的 `RecurrenceRule` 永远是领域对象。
import 'package:now_todo/data/database/app_database.dart' as database;
import 'package:now_todo/data/repositories/backup_repository.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/recurrence_repository.dart';
import 'package:now_todo/data/repositories/reminder_repository.dart';
import 'package:now_todo/data/repositories/settings_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late database.AppDatabase db;
  late SettingsRepository settings;
  late BackupRepository backup;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    settings = SettingsRepository(db);
    backup = BackupRepository(db, settings);
  });

  tearDown(() async {
    await db.close();
  });

  /// 造一份「什么都有」的库：清单、标签、任务、子任务、提醒、重复规则、专注记录。
  ///
  /// 返回那条任务的 id。日期全部写死，测试才不会随执行时刻漂。
  Future<String> seedFull(database.AppDatabase target) async {
    final ListRepository lists = ListRepository(target);
    final TaskRepository tasks = TaskRepository(target);
    final ReminderRepository reminders = ReminderRepository(target);
    final RecurrenceRepository recurrence = RecurrenceRepository(target);
    final FocusSessionRepository sessions = FocusSessionRepository(target);

    final String workId = await lists.create('工作', color: 0xFF4CAF50);
    final String ruleId = await recurrence.create(
      RecurrenceRule(
        startsOn: DateTime(2026, 1, 5, 9),
        frequency: RecurrenceFrequency.weekly,
        byWeekday: <int>{1, 3},
      ),
    );
    final String taskId = await tasks.create(
      title: '交周报',
      note: '周五之前',
      dueDate: DateTime(2026, 1, 9, 9).utcMillis,
      dueDateHasTime: true,
      priority: TaskPriority.high,
      listId: workId,
      recurrenceRuleId: ruleId,
    );
    await tasks.setTaskTags(taskId, <String>['工作']);
    await tasks.addSubtask(taskId, '收集数据');
    await reminders.add(
      taskId: taskId,
      remindAt: DateTime(2026, 1, 9, 8).utcMillis,
      repeatType: ReminderRepeatType.daily,
    );
    final String sessionId = await sessions.start(
      at: DateTime(2026, 1, 5, 10),
      logicalDate: dayOnlyMillis(DateTime(2026, 1, 5)),
      taskId: taskId,
      plan: const Duration(minutes: 25),
    );
    await sessions.finish(sessionId, at: DateTime(2026, 1, 5, 10, 25));
    return taskId;
  }

  /// 手搓一份只有一条任务的备份。
  ///
  /// 走 codec 编解码再读回来会让「文件里的 updatedAt 是多少」变得绕，合并模式的
  /// 取舍就是围绕这个时间戳转的，所以直接把 [BackupData] 拼出来。
  BackupData oneTaskFile({
    required String title,
    required int updatedAt,
    AppPreferences preferences = const AppPreferences(),
  }) => BackupData(
    exportedAt: 0,
    app: const BackupAppInfo(
      name: 'now_todo',
      version: 'test',
      schemaVersion: 4,
    ),
    taskLists: const <BackupListRow>[],
    tags: const <BackupTagRow>[],
    tasks: <BackupTaskRow>[
      BackupTaskRow(
        id: 'task-1',
        title: title,
        note: null,
        dueDate: null,
        dueDateHasTime: false,
        priority: 0,
        status: 0,
        listId: null,
        recurrenceRuleId: null,
        createdAt: 1000,
        updatedAt: updatedAt,
        completedAt: null,
        estimatedPomodoros: null,
      ),
    ],
    taskTags: const <BackupTaskTagRow>[],
    subtasks: const <BackupSubtaskRow>[],
    reminders: const <BackupReminderRow>[],
    recurrenceRules: const <BackupRecurrenceRow>[],
    focusSessions: const <BackupFocusSessionRow>[],
    settings: preferences,
  );

  /// 在本地放一条 id 与 [oneTaskFile] 相同的任务，时间戳听调用方的。
  Future<void> seedLocalTask({
    required String title,
    required int updatedAt,
  }) async {
    await db
        .into(db.tasks)
        .insert(
          database.TasksCompanion.insert(
            id: 'task-1',
            title: title,
            createdAt: 1000,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<database.AppDatabase> emptyDatabase() async {
    final database.AppDatabase other = createTestDatabase();
    addTearDown(other.close);
    await other.ensureInitialized();
    return other;
  }

  group('导出', () {
    test('空库也能导出一份合法文件', () async {
      final BackupData data = await backup.export(appVersion: 'test');

      expect(data.taskLists, hasLength(1));
      expect(data.taskLists.single.id, AppConstants.inboxListId);
      expect(data.tasks, isEmpty);
      expect(data.settings.focusMinutes, 25);
      // 空库导出的也必须能读回来，否则「先备份再恢复」这条路第一步就断了。
      expect(() => decodeBackup(encodeBackup(data)), returnsNormally);
    });

    test('九张表都跟着出来', () async {
      final String taskId = await seedFull(db);
      final BackupData data = await backup.export(appVersion: '1.2.3+4');

      expect(data.app.version, '1.2.3+4');
      expect(data.app.name, AppConstants.databaseName);
      expect(data.app.schemaVersion, db.schemaVersion);
      expect(data.taskLists.map((BackupListRow row) => row.name), <String>[
        '收件箱',
        '工作',
      ]);
      expect(data.tags.single.name, '工作');
      expect(data.tasks.single.title, '交周报');
      expect(data.tasks.single.priority, TaskPriority.high.index);
      expect(data.tasks.single.listId, isNotNull);
      expect(data.subtasks.single.title, '收集数据');
      expect(data.reminders.single.repeatType, ReminderRepeatType.daily.index);
      expect(data.recurrenceRules.single.byWeekday, '1,3');
      expect(
        data.recurrenceRules.single.startsOn,
        DateTime(2026, 1, 5, 9).utcMillis,
      );
      expect(data.focusSessions.single.actualSeconds, 25 * 60);
      expect(data.taskTags.single.taskId, taskId);
      expect(data.taskTags.single.tagId, data.tags.single.id);
    });
  });

  group('覆盖导入', () {
    test('先清空本地，再整份写进去', () async {
      final String taskId = await seedFull(db);
      final BackupData file = await backup.export(appVersion: 'test');

      final database.AppDatabase other = await emptyDatabase();
      await TaskRepository(other).create(title: '这边独有的任务');
      final BackupRepository otherBackup = BackupRepository(
        other,
        SettingsRepository(other),
      );

      final ImportOutcome outcome = await otherBackup.importData(
        file,
        mode: ImportMode.overwrite,
      );

      expect(outcome.counts['tasks'], 1);
      expect(outcome.skipped, isEmpty, reason: '覆盖模式没有「跳过」这一说');
      final List<database.Task> tasks = await other.select(other.tasks).get();
      expect(tasks.single.id, taskId);
      expect(tasks.single.title, '交周报');
    });

    test('导出再导入：data 段一模一样', () async {
      await seedFull(db);
      final BackupData file = await backup.export(appVersion: 'test');

      final database.AppDatabase other = await emptyDatabase();
      final BackupRepository otherBackup = BackupRepository(
        other,
        SettingsRepository(other),
      );
      await otherBackup.importData(file, mode: ImportMode.overwrite);

      final BackupData again = await otherBackup.export(appVersion: 'test');
      // 八张表 + 设置整段深比较：一行少一个字段、时间戳被改写都会在这里露出来。
      expect(encodeBackupToMap(again)['data'], encodeBackupToMap(file)['data']);
    });

    test('没结束的专注记录不搬：那是设备上的当前状态', () async {
      await TaskRepository(db).create(title: '写周报');
      // start 之后不 finish：库里留一段「正在计时」的记录。
      await FocusSessionRepository(db).start(
        at: DateTime(2026, 1, 5, 10),
        logicalDate: dayOnlyMillis(DateTime(2026, 1, 5)),
      );
      final BackupData file = await backup.export(appVersion: 'test');
      expect(file.focusSessions.single.endedAt, isNull);

      final database.AppDatabase other = await emptyDatabase();
      final ImportOutcome outcome = await BackupRepository(
        other,
        SettingsRepository(other),
      ).importData(file, mode: ImportMode.overwrite);

      expect(outcome.counts['focusSessions'], 0);
      expect(outcome.skipped['focusSessions'], 1);
      expect(await other.select(other.focusSessions).get(), isEmpty);
    });

    test('收件箱不会跟在文件后面消失', () async {
      // 这份文件里一个清单都没有；覆盖模式先清空本地，收件箱得靠 ensureInitialized 兜回来。
      await backup.importData(
        oneTaskFile(title: '文件里的', updatedAt: 2000),
        mode: ImportMode.overwrite,
      );

      final List<database.TaskList> lists = await db.select(db.taskLists).get();
      expect(lists.map((database.TaskList row) => row.id), <String>[
        AppConstants.inboxListId,
      ]);
    });
  });

  group('合并导入', () {
    test('本地那份更新就保留本地', () async {
      await seedLocalTask(title: '本地改过的标题', updatedAt: 3000);

      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(title: '文件里的标题', updatedAt: 2000),
        mode: ImportMode.merge,
      );

      expect(outcome.skipped['tasks'], 1);
      expect(outcome.counts['tasks'], 0);
      expect((await db.select(db.tasks).get()).single.title, '本地改过的标题');
    });

    test('文件那份更新就覆盖本地', () async {
      await seedLocalTask(title: '本地旧标题', updatedAt: 1000);

      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(title: '文件里的标题', updatedAt: 2000),
        mode: ImportMode.merge,
      );

      expect(outcome.counts['tasks'], 1);
      expect((await db.select(db.tasks).get()).single.title, '文件里的标题');
    });

    test('时间戳一样时保留本地', () async {
      await seedLocalTask(title: '本地', updatedAt: 2000);

      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(title: '文件', updatedAt: 2000),
        mode: ImportMode.merge,
      );

      expect(outcome.skipped['tasks'], 1);
      expect((await db.select(db.tasks).get()).single.title, '本地');
    });

    test('本地独有的东西不动', () async {
      await TaskRepository(db).create(title: '本地独有的');
      await backup.importData(
        oneTaskFile(title: '文件里的', updatedAt: 2000),
        mode: ImportMode.merge,
      );

      final List<database.Task> tasks = await db.select(db.tasks).get();
      expect(tasks.map((database.Task row) => row.title), <String>[
        '本地独有的',
        '文件里的',
      ]);
    });

    test('同一份文件导入两次，第二次什么都不用改', () async {
      await seedFull(db);
      final BackupData file = await backup.export(appVersion: 'test');
      final database.AppDatabase other = await emptyDatabase();
      final BackupRepository otherBackup = BackupRepository(
        other,
        SettingsRepository(other),
      );

      final ImportOutcome first = await otherBackup.importData(
        file,
        mode: ImportMode.merge,
      );
      expect(first.counts['tasks'], 1);
      // 收件箱本地本来就有（ensureInitialized 建的，时间戳还比文件里那份新），
      // 只有「工作」是新插的。
      expect(first.counts['taskLists'], 1);
      expect(first.skipped['taskLists'], 1);

      final ImportOutcome second = await otherBackup.importData(
        file,
        mode: ImportMode.merge,
      );
      final Map<String, int> written = Map<String, int>.from(second.counts)
        ..remove('settings');
      expect(written.values.every((int value) => value == 0), isTrue);
      expect(second.skipped['tasks'], 1);
      expect(second.skipped['taskLists'], 2);
      expect(second.skipped['focusSessions'], 1);
    });

    test('同名标签认成同一个，标签关系跟着改指', () async {
      final String taskId = await seedFull(db);
      final BackupData file = await backup.export(appVersion: 'test');
      final String fileTagId = file.tags.single.id;

      final database.AppDatabase other = await emptyDatabase();
      // 名字一样、id 不一样：「工作」在两边是同一个标签。
      final String localTagId = await TagRepository(other).create('工作');
      expect(localTagId, isNot(fileTagId));

      final ImportOutcome outcome = await BackupRepository(
        other,
        SettingsRepository(other),
      ).importData(file, mode: ImportMode.merge);

      final List<database.Tag> tags = await other.select(other.tags).get();
      expect(tags.single.id, localTagId, reason: '不该多出一个同名标签');
      final List<database.TaskTag> links = await other
          .select(other.taskTags)
          .get();
      expect(links.single.taskId, taskId);
      expect(links.single.tagId, localTagId, reason: '关系要指到本地那个标签，不然外键会拒');
      expect(outcome.skipped['tags'], 1);
    });
  });

  group('设置', () {
    test('合并导入不动本机改过的设置', () async {
      await settings.update(themeMode: ThemeModeSetting.dark);

      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(
          title: '文件里的',
          updatedAt: 2000,
          preferences: const AppPreferences(
            midnightMode: true,
            focusMinutes: 30,
          ),
        ),
        mode: ImportMode.merge,
      );

      expect(outcome.skipped['settings'], 1);
      final AppPreferences after = await settings.load();
      expect(after.themeMode, ThemeModeSetting.dark);
      expect(after.midnightMode, isFalse);
      expect(after.focusMinutes, 25);
    });

    test('合并导入：本机还是出厂值就接受文件里的设置', () async {
      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(
          title: '文件里的',
          updatedAt: 2000,
          preferences: const AppPreferences(
            midnightMode: true,
            focusMinutes: 30,
          ),
        ),
        mode: ImportMode.merge,
      );

      expect(outcome.counts['settings'], 1);
      final AppPreferences after = await settings.load();
      expect(after.midnightMode, isTrue);
      expect(after.focusMinutes, 30);
    });

    test('覆盖导入：设置整份换成文件里的', () async {
      await settings.update(themeMode: ThemeModeSetting.dark);

      final ImportOutcome outcome = await backup.importData(
        oneTaskFile(
          title: '文件里的',
          updatedAt: 2000,
          preferences: const AppPreferences(focusMinutes: 50),
        ),
        mode: ImportMode.overwrite,
      );

      expect(outcome.counts['settings'], 1);
      final AppPreferences after = await settings.load();
      expect(after.themeMode, ThemeModeSetting.system);
      expect(after.focusMinutes, 50);
    });
  });

  test('写到一半撞上库的约束：数据库保持导入前的样子', () async {
    await TaskRepository(db).create(title: '本地原有的');

    final BackupData broken = BackupData(
      exportedAt: 0,
      app: const BackupAppInfo(
        name: 'now_todo',
        version: 'test',
        schemaVersion: 4,
      ),
      taskLists: <BackupListRow>[
        const BackupListRow(
          id: 'list-x',
          name: '文件里的清单',
          color: null,
          isBuiltIn: false,
          sortOrder: 0,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      tags: const <BackupTagRow>[],
      tasks: <BackupTaskRow>[
        // 标题是空串：codec 拦不住（它只管类型与引用），数据库的 CHECK 拦得住。
        const BackupTaskRow(
          id: 'task-x',
          title: '',
          note: null,
          dueDate: null,
          dueDateHasTime: false,
          priority: 0,
          status: 0,
          listId: 'list-x',
          recurrenceRuleId: null,
          createdAt: 1,
          updatedAt: 1,
          completedAt: null,
          estimatedPomodoros: null,
        ),
      ],
      taskTags: const <BackupTaskTagRow>[],
      subtasks: const <BackupSubtaskRow>[],
      reminders: const <BackupReminderRow>[],
      recurrenceRules: const <BackupRecurrenceRow>[],
      focusSessions: const <BackupFocusSessionRow>[],
      settings: const AppPreferences(),
    );

    await expectLater(
      () => backup.importData(broken, mode: ImportMode.overwrite),
      throwsA(isA<Exception>()),
    );

    // 单事务：先被清空的清单、先写进去的那条任务，都得跟着回滚。
    final List<database.Task> tasks = await db.select(db.tasks).get();
    expect(tasks.single.title, '本地原有的');
    final List<database.TaskList> lists = await db.select(db.taskLists).get();
    expect(lists.map((database.TaskList row) => row.id), <String>[
      AppConstants.inboxListId,
    ]);
  });
}
