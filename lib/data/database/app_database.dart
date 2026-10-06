import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/enums.dart';
import '../../core/utils/time.dart';
import 'tables/app_settings.dart';
import 'tables/focus_sessions.dart';
import 'tables/recurrence_and_reminders.dart';
import 'tables/subtasks.dart';
import 'tables/tags.dart';
import 'tables/task_lists.dart';
import 'tables/tasks.dart';

part 'app_database.g.dart';

/// 应用数据库。
///
/// 这一层是唯一允许接触 Drift 生成类型的地方——`features/` 下的代码
/// 只能通过 `data/repositories/` 拿到领域对象（见 `docs/ARCHITECTURE.md` §3）。
/// 违反这条会让「换掉数据库」从一次重构变成一次重写。
@DriftDatabase(
  tables: <Type>[
    TaskLists,
    Tasks,
    Tags,
    TaskTags,
    Subtasks,
    RecurrenceRules,
    Reminders,
    AppSettings,
    FocusSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试用：传入内存数据库。
  ///
  /// ```dart
  /// final db = AppDatabase.forTesting(NativeDatabase.memory());
  /// ```
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 逐版本往上迁。**不要**用 `deleteTable` / 重建库来「解决」冲突——
      // 那等于删用户数据。见 docs/ARCHITECTURE.md §6。
      for (int version = from; version < to; version++) {
        switch (version) {
          // v1 → v2：新增强提醒开关（M5）。
          //
          // `withDefault` 保证老行会被填上 false，所以这里只加列、不回填。
          // 新列取默认值本来就是用户该得到的结果：这个功能在他装这个版本
          // 之前并不存在，默认关是唯一说得通的起点。
          case 1:
            await m.addColumn(appSettings, appSettings.strongReminders);

          // v2 → v3：专注计时（F2）。
          //
          // 落一张新表 + 给两张老表加列。全部是加列与建表，没有回填：
          // 新表的每一列对老用户来说都该是默认值。
          //
          // **`createTable` 不会顺手建 `@TableIndex` 声明的索引**（只有
          // `createAll` 会，它是按 `allSchemaEntities` 逐项建的）。漏掉这三行
          // 不会有任何报错，只会让统计查询在数据变多之后慢下来，而那时候
          // 已经很难归因了——所以索引必须显式建。
          case 2:
            await m.createTable(focusSessions);
            await m.createIndex(focusSessionsLogicalDate);
            await m.createIndex(focusSessionsTaskId);
            await m.createIndex(focusSessionsStartedAt);
            await m.addColumn(tasks, tasks.estimatedPomodoros);
            await m.addColumn(appSettings, appSettings.focusMinutes);
            await m.addColumn(appSettings, appSettings.shortBreakMinutes);
            await m.addColumn(appSettings, appSettings.longBreakMinutes);
            await m.addColumn(appSettings, appSettings.roundsBeforeLongBreak);
            await m.addColumn(appSettings, appSettings.autoStartNext);
            await m.addColumn(appSettings, appSettings.defaultTimerMode);
            await m.addColumn(appSettings, appSettings.midnightMode);
            await m.addColumn(appSettings, appSettings.midnightEndHour);

          // v3 → v4：重复任务（M4）。
          //
          // 表在 v1 就建好了，只是一直没人往里写。加的两列是系列的锚点与
          // 次数上限，理由写在表定义里。同样是加列、不回填。
          case 3:
            await m.addColumn(recurrenceRules, recurrenceRules.startsOn);
            await m.addColumn(recurrenceRules, recurrenceRules.endCount);
        }
      }
    },
    beforeOpen: (details) async {
      // sqlite3 **默认不打开外键约束**，必须每条连接显式打开，
      // 否则所有 `onDelete: cascade / setNull` 都是摆设：
      // 删任务不会连带删子任务，删清单也不会把任务的 listId 置空。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 幂等的首次初始化：补齐内置清单与设置行。
  ///
  /// 为什么不放在 `onCreate`：`onCreate` 只在**建库那一次**执行，
  /// 而这里还要负责「旧版本升级后补齐新增的内置行」。写成幂等的普通方法，
  /// 每次启动都调用，代价只是一两条 `SELECT`。
  ///
  /// 幂等靠「查不到才插入」实现，不靠时间戳或版本号——
  /// 用户完全可能手动删掉收件箱，那下次启动就会重新长出来，这是想要的。
  Future<void> ensureInitialized() async {
    final int now = nowUtcMillis();

    await transaction(() async {
      final AppSetting? settings = await select(appSettings).getSingleOrNull();
      if (settings == null) {
        await into(appSettings).insert(
          AppSettingsCompanion.insert(
            initializedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final TaskList? inbox =
          await (select(taskLists)
                ..where(($TaskListsTable t) => t.isBuiltIn.equals(true))
                ..limit(1))
              .getSingleOrNull();
      if (inbox == null) {
        await into(taskLists).insert(
          TaskListsCompanion.insert(
            id: AppConstants.inboxListId,
            name: '收件箱',
            isBuiltIn: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: AppConstants.databaseName,
    native: const DriftNativeOptions(
      // 让同一个数据库文件只由一个后台 isolate 持有。
      // 不加这个，将来任何一处不小心多建了一个 AppDatabase 实例，
      // 就会变成两个连接各自持有一份缓存，写冲突变得很难查。
      shareAcrossIsolates: true,
    ),
  );
}
