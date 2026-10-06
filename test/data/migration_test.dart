// 数据库结构变更的护栏。
//
// 这里校验的是「**当前代码里的表结构**」与「**`drift_schemas/` 里签入的快照**」
// 是否仍然一致。一旦有人改了表/列却忘了提升 `schemaVersion`、忘了重新导出快照，
// 这个用例就会红。
//
// 三个产物都由命令生成，**不要手改**：
//
// ```
// dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/
// dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/
// ```
//
// 加新版本的完整五步见 `docs/ARCHITECTURE.md` §6.1。
//
// 覆盖策略：**每一条历史版本到当前的路径都要有一条**。只测「上一版 → 当前版」
// 会漏掉跨版本升级——用户从 1.0.0 直接装 1.2.0 是常态，不是例外。
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/data/database/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;

/// 当前代码里的版本。每个用例都拿它当迁移目标，改 `schemaVersion` 时只改这一处。
const int kCurrentVersion = 4;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('全新安装的表结构与最新快照一致', () async {
    final schema = await verifier.schemaAt(kCurrentVersion);
    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());

    // migrateAndValidate 会打开库、跑迁移，再读 sqlite_schema 逐项比对：
    // 只有当前代码产出的结构与目标版本的快照**完全一致**时才会正常返回，
    // 否则抛 SchemaMismatch 并把差异列出来。
    //
    // 它同时会校验索引：`focus_sessions` 的三条索引漏建也会在这里红。
    await verifier.migrateAndValidate(db, kCurrentVersion);

    await db.close();
    schema.close();
  });

  test('从 v1 直接升到 v4 之后，结构与 v4 快照一致', () async {
    final schema = await verifier.schemaAt(1);
    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());

    // 第二个参数是**迁移的目标版本**，不是起点。这里库是从 v1 快照建的，
    // 所以 drift 会真的跑一遍 onUpgrade(1 → 4)，再拿 v4 快照比对结果。
    // 这一步同时证明 v1 → v2 → v3 → v4 三段能连着跑。
    await verifier.migrateAndValidate(db, kCurrentVersion);

    await db.close();
    schema.close();
  });

  test('从 v2 升到 v4 之后，结构与 v4 快照一致', () async {
    final schema = await verifier.schemaAt(2);
    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());

    await verifier.migrateAndValidate(db, kCurrentVersion);

    await db.close();
    schema.close();
  });

  test('从 v3 升到 v4 之后，结构与 v4 快照一致', () async {
    final schema = await verifier.schemaAt(3);
    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());

    await verifier.migrateAndValidate(db, kCurrentVersion);

    await db.close();
    schema.close();
  });

  test('v1 升到 v4 不丢数据，新表与新增的设置列取到默认值', () async {
    final schema = await verifier.schemaAt(1);

    // 先在「v1 的视角」上写数据，模拟一个升级前就已经在用的库。
    // 这一步必须用另一个连接：同一个连接不能同时被两个 GeneratedDatabase
    // 持有，用完要先关掉。
    final v1.DatabaseAtV1 oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.customStatement(
      'INSERT INTO app_settings '
      '(id, theme_mode, default_view, notifications_enabled, initialized_at) '
      'VALUES (1, 2, 1, 1, 111)',
    );
    await oldDb.customStatement(
      'INSERT INTO tasks '
      '(id, title, note, due_date, due_date_has_time, priority, status, '
      ' created_at, updated_at) '
      "VALUES ('t1', '老任务', '升级前就有的备注', 222, 1, 3, 0, 111, 111)",
    );
    await oldDb.customStatement(
      'INSERT INTO task_lists (id, name, is_built_in, sort_order, created_at, updated_at) '
      "VALUES ('l1', '老清单', 0, 0, 111, 111)",
    );
    await oldDb.close();

    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, kCurrentVersion);

    // 迁移用的是 addColumn，老行是靠列的默认值补齐的——不是靠回填语句。
    // 所以这里取到的默认值就是「默认值确实生效」的证据；一旦默认值丢了，
    // 这些列会是 NULL，读取时直接抛。
    final AppSetting settings = await db.select(db.appSettings).getSingle();
    expect(settings.themeMode, ThemeModeSetting.dark);
    expect(settings.defaultView, DefaultView.all);
    expect(settings.notificationsEnabled, isTrue);
    expect(settings.strongReminders, isFalse);
    // 专注相关的默认值：标准番茄钟那一套。
    expect(settings.focusMinutes, 25);
    expect(settings.shortBreakMinutes, 5);
    expect(settings.longBreakMinutes, 15);
    expect(settings.roundsBeforeLongBreak, 4);
    expect(settings.autoStartNext, isFalse);
    expect(settings.defaultTimerMode, FocusTimerMode.countDown);
    expect(settings.midnightMode, isFalse);
    expect(settings.midnightEndHour, 4);

    // 数据本身必须原样还在：迁移出错的典型表现不是报错，而是把用户的东西
    // 悄悄抹掉——那种 bug 只有在有这条断言时才会被发现。
    final Task task = await db.select(db.tasks).getSingle();
    expect(task.id, 't1');
    expect(task.title, '老任务');
    expect(task.note, '升级前就有的备注');
    expect(task.dueDate, 222);
    expect(task.dueDateHasTime, isTrue);
    expect(task.priority, TaskPriority.high);
    expect(task.estimatedPomodoros, isNull);

    final TaskList list = await db.select(db.taskLists).getSingle();
    expect(list.id, 'l1');
    expect(list.name, '老清单');

    // 新表是空的，不是「建好了但塞了东西」。
    expect(await db.select(db.focusSessions).get(), isEmpty);

    await db.close();
    schema.close();
  });

  test('v2 升到 v4 时用户自己调过的设置不丢', () async {
    final schema = await verifier.schemaAt(2);

    final v2.DatabaseAtV2 oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb.customStatement(
      'INSERT INTO app_settings '
      '(id, theme_mode, default_view, notifications_enabled, strong_reminders, '
      ' initialized_at) '
      'VALUES (1, 1, 2, 0, 1, 111)',
    );
    await oldDb.close();

    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, kCurrentVersion);

    final AppSetting settings = await db.select(db.appSettings).getSingle();
    // 这三条是用户改过的值，必须原样活着。
    expect(settings.themeMode, ThemeModeSetting.light);
    expect(settings.defaultView, DefaultView.completed);
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.strongReminders, isTrue);
    // 而 v3 新加的列落到默认值。
    expect(settings.focusMinutes, 25);
    expect(settings.midnightMode, isFalse);

    await db.close();
    schema.close();
  });

  test('v3 升到 v4 时，老重复规则的两列取到默认值，规则本身还在', () async {
    final schema = await verifier.schemaAt(3);

    final v3.DatabaseAtV3 oldDb = v3.DatabaseAtV3(schema.newConnection());
    await oldDb.customStatement(
      'INSERT INTO recurrence_rules '
      '(id, frequency, interval, by_weekday, by_month_day, end_date, created_at) '
      "VALUES ('r1', 1, 2, '1,3', NULL, NULL, 111)",
    );
    await oldDb.close();

    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, kCurrentVersion);

    final RecurrenceRule rule = await db.select(db.recurrenceRules).getSingle();
    expect(rule.id, 'r1');
    expect(rule.frequency, RecurrenceFrequency.weekly);
    expect(rule.interval, 2);
    expect(rule.byWeekday, '1,3');
    // startsOn 的默认值是 0：SQLite 要求给已有的表加非空列时必须给默认值，
    // 0 换算出来是 1970 年，一眼能看出是「没写过」。仓储层读到 0 会退回用
    // 规则的创建时间兜底。
    expect(rule.startsOn, 0);
    expect(rule.endCount, isNull);

    await db.close();
    schema.close();
  });

  test('新表的三条索引都建出来了', () async {
    final schema = await verifier.schemaAt(2);
    final AppDatabase db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, kCurrentVersion);

    // 索引漏了不会有任何报错，只会让统计查询在数据变多之后慢下来，
    // 而那时候已经很难归因了。所以这里显式问一次 sqlite_master。
    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'focus_sessions'",
        )
        .get();

    final Set<String> names = rows
        .map((QueryRow r) => r.read<String>('name'))
        .toSet();
    expect(names, contains('focus_sessions_logical_date'));
    expect(names, contains('focus_sessions_task_id'));
    expect(names, contains('focus_sessions_started_at'));

    await db.close();
    schema.close();
  });
}
