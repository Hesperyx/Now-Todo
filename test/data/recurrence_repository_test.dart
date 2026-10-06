import 'dart:async';

// 只要 `Value`：drift 也导出 `isNull` / `isNotNull`，全量导入会和 matcher 撞名。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';
import 'package:now_todo/core/utils/time.dart';
// 领域里的规则与 drift 生成的数据类同名，这里给数据库文件加前缀，让不带前缀的
// `RecurrenceRule` 永远是领域对象。
import 'package:now_todo/data/database/app_database.dart' as database;
import 'package:now_todo/data/repositories/recurrence_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late database.AppDatabase db;
  late RecurrenceRepository recurrence;
  late TaskRepository tasks;
  late String taskId;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    recurrence = RecurrenceRepository(db);
    tasks = TaskRepository(db);
    taskId = await tasks.create(title: '交周报');
  });

  tearDown(() async {
    await db.close();
  });

  DateTime d(int year, int month, int day, [int hour = 9, int minute = 0]) =>
      DateTime(year, month, day, hour, minute);

  RecurrenceRule rule({
    required DateTime startsOn,
    RecurrenceFrequency frequency = RecurrenceFrequency.daily,
    int interval = 1,
    Set<int> byWeekday = const <int>{},
    Set<int> byMonthDay = const <int>{},
    DateTime? endDate,
    int? endCount,
  }) => RecurrenceRule(
    startsOn: startsOn,
    frequency: frequency,
    interval: interval,
    byWeekday: byWeekday,
    byMonthDay: byMonthDay,
    endDate: endDate,
    endCount: endCount,
  );

  /// 把规则挂到任务上。`apply()` 只负责规则表，任务那一列由调用方写，
  /// 和编辑页真正的做法一致。
  Future<void> link(String id, String? ruleId) => tasks.update(
    id,
    title: '交周报',
    note: null,
    dueDate: null,
    dueDateHasTime: false,
    priority: TaskPriority.none,
    listId: null,
    recurrenceRuleId: ruleId,
  );

  Future<int> ruleRowCount() async =>
      (await db.select(db.recurrenceRules).get()).length;

  /// 迁移测试之外的读法：直接看表里那一行长什么样。
  Future<database.RecurrenceRule?> rawRule(String id) async {
    final List<database.RecurrenceRule> rows = await (db.select(
      db.recurrenceRules,
    )..where((r) => r.id.equals(id))).get();
    return rows.isEmpty ? null : rows.single;
  }

  group('新建与读取', () {
    test('新建之后读得回来，字段都在', () async {
      final String id = await recurrence.create(
        rule(
          startsOn: d(2030, 5, 1),
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          byWeekday: <int>{1, 3},
          endCount: 10,
        ),
      );
      await link(taskId, id);

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded, isNotNull);
      expect(loaded!.startsOn, d(2030, 5, 1));
      expect(loaded.frequency, RecurrenceFrequency.weekly);
      expect(loaded.interval, 2);
      expect(loaded.byWeekday, <int>{1, 3});
      expect(loaded.byMonthDay, isEmpty);
      expect(loaded.endCount, 10);
      expect(loaded.endDate, isNull);
    });

    test('没有规则的任务读回来是 null，任务不存在也是 null', () async {
      expect(await recurrence.findForTask(taskId), isNull);
      expect(await recurrence.findForTask('不存在的任务'), isNull);
    });

    test('锚点保住时刻：每天 09:30 的系列，读回来还是 09:30', () async {
      final String id = await recurrence.create(
        rule(startsOn: d(2030, 5, 1, 9, 30)),
      );
      await link(taskId, id);

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.startsOn, d(2030, 5, 1, 9, 30));
      expect(loaded.startsOn.hour, 9);
      expect(loaded.startsOn.minute, 30);
    });

    test('结束日期存的是本地日期，带上来的时刻会被丢掉', () async {
      final String id = await recurrence.create(
        rule(startsOn: d(2030, 5, 1), endDate: d(2030, 12, 31, 15, 45)),
      );
      await link(taskId, id);

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.endDate, DateTime(2030, 12, 31), reason: '存成本地零点');
    });

    test('越界值在写入前就被收口，不让它进数据库', () async {
      final String id = await recurrence.create(
        rule(
          startsOn: d(2030, 5, 1),
          interval: 0,
          byWeekday: <int>{0, 8},
          byMonthDay: <int>{0, 32},
          endCount: 0,
        ),
      );
      await link(taskId, id);

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.interval, 1);
      expect(loaded.byWeekday, isEmpty);
      expect(loaded.byMonthDay, isEmpty);
      expect(loaded.endCount, isNull);
      expect((await rawRule(id))!.byWeekday, isNull, reason: '空集合存 NULL，不是空串');
    });

    test('update 换掉整条规则，锚点的时刻也保住', () async {
      final String id = await recurrence.create(rule(startsOn: d(2030, 5, 1)));
      await link(taskId, id);

      await recurrence.update(
        id,
        rule(
          startsOn: d(2030, 6, 10, 8, 15),
          frequency: RecurrenceFrequency.monthly,
          byMonthDay: <int>{10},
          endDate: d(2031, 6, 10),
        ),
      );

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.startsOn, d(2030, 6, 10, 8, 15));
      expect(loaded.frequency, RecurrenceFrequency.monthly);
      expect(loaded.byMonthDay, <int>{10});
      expect(loaded.endDate, DateTime(2031, 6, 10));
      expect(await ruleRowCount(), 1, reason: '是改写那一条，不是又插一条');
    });

    test('watchForTask 会推出新值，规则行被改时也会重新发射', () async {
      final List<RecurrenceRule?> seen = <RecurrenceRule?>[];
      final StreamSubscription<RecurrenceRule?> sub = recurrence
          .watchForTask(taskId)
          .listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen, <RecurrenceRule?>[null]);

      final String id = await recurrence.create(rule(startsOn: d(2030, 5, 1)));
      await link(taskId, id);
      await pumpEventQueue();
      expect(seen.last, isNotNull);
      expect(seen.last!.startsOn, d(2030, 5, 1));

      await recurrence.update(id, rule(startsOn: d(2030, 7, 1)));
      await pumpEventQueue();
      expect(seen.last!.startsOn, d(2030, 7, 1));
    });

    test('两条任务各自的规则互不干扰', () async {
      final String other = await tasks.create(title: '倒垃圾');
      final String mine = await recurrence.create(
        rule(startsOn: d(2030, 5, 1)),
      );
      final String theirs = await recurrence.create(
        rule(startsOn: d(2030, 8, 1), frequency: RecurrenceFrequency.yearly),
      );
      await link(taskId, mine);
      await link(other, theirs);

      expect((await recurrence.findForTask(taskId))!.startsOn, d(2030, 5, 1));
      expect((await recurrence.findForTask(other))!.startsOn, d(2030, 8, 1));

      await recurrence.update(mine, rule(startsOn: d(2030, 5, 2)));
      expect((await recurrence.findForTask(other))!.startsOn, d(2030, 8, 1));
    });

    test('一个规则可以被同系列的几条实例共用', () async {
      final String second = await tasks.create(title: '交周报');
      final String id = await recurrence.create(rule(startsOn: d(2030, 5, 1)));
      await link(taskId, id);
      await link(second, id);

      await tasks.delete(taskId);

      expect(await recurrence.findForTask(taskId), isNull);
      expect(
        (await recurrence.findForTask(second))!.startsOn,
        d(2030, 5, 1),
        reason: '删掉一条实例，规则本身还归别的实例用',
      );
      expect(await ruleRowCount(), 1);
    });
  });

  group('apply · 改一条实例的重复设置', () {
    test('原本不重复：新建一条规则，返回它的 id', () async {
      final String? id = await recurrence.apply(
        taskId: taskId,
        draft: rule(startsOn: d(2030, 5, 1)),
      );
      expect(id, isNotNull);
      await link(taskId, id);

      expect((await recurrence.findForTask(taskId))!.startsOn, d(2030, 5, 1));
      expect(await ruleRowCount(), 1);
    });

    test('draft 为 null：规则删掉，实例留下', () async {
      final String id = await recurrence.create(rule(startsOn: d(2030, 5, 1)));
      await link(taskId, id);

      final String? next = await recurrence.apply(taskId: taskId, draft: null);
      expect(next, isNull);
      await link(taskId, next);

      expect(await recurrence.findForTask(taskId), isNull);
      expect(await ruleRowCount(), 0);
      expect(await tasks.findById(taskId), isNotNull, reason: '任务本身不该被连坐');
    });

    test('仅此一次：锚点不动，别的字段照改', () async {
      final String id = await recurrence.create(
        rule(startsOn: d(2030, 5, 1), byWeekday: <int>{1, 3}),
      );
      await link(taskId, id);

      final String? next = await recurrence.apply(
        taskId: taskId,
        draft: rule(startsOn: d(2030, 5, 20), byWeekday: <int>{5}),
        keepSeriesAnchor: true,
      );

      expect(next, id, reason: '还是同一条规则');
      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.startsOn, d(2030, 5, 1), reason: '锚点保持原样');
      expect(loaded.byWeekday, <int>{5}, reason: '别的字段照改');
      expect(await ruleRowCount(), 1);
    });

    test('此后全部：锚点跟着 draft 走', () async {
      final String id = await recurrence.create(
        rule(startsOn: d(2030, 5, 1), byWeekday: <int>{1, 3}),
      );
      await link(taskId, id);

      final String? next = await recurrence.apply(
        taskId: taskId,
        draft: rule(startsOn: d(2030, 5, 20), byWeekday: <int>{5}),
      );

      expect(next, id);
      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.startsOn, d(2030, 5, 20));
      expect(loaded.byWeekday, <int>{5});
      expect(await ruleRowCount(), 1);
    });

    test('apply 只碰规则表，任务上的 id 还是调用方写', () async {
      final String first = await recurrence.create(
        rule(startsOn: d(2030, 5, 1)),
      );
      await link(taskId, first);

      // 不调 link：任务那一列还是旧 id，`apply` 不该自作主张改它。
      final String? next = await recurrence.apply(
        taskId: taskId,
        draft: rule(startsOn: d(2030, 5, 2)),
      );
      expect(next, first);
      expect((await tasks.findById(taskId))!.recurrenceRuleId, first);
    });
  });

  group('坏数据不能让它挂掉', () {
    test('锚点为 0 的老行用创建时间兜底', () async {
      // v4 之前没有任何代码写过 startsOn，所以老行读出来是列默认值 0。
      await db
          .into(db.recurrenceRules)
          .insert(
            database.RecurrenceRulesCompanion.insert(
              id: 'legacy',
              frequency: RecurrenceFrequency.daily,
              createdAt: 111,
            ),
          );
      await link(taskId, 'legacy');

      final RecurrenceRule? loaded = await recurrence.findForTask(taskId);
      expect(loaded!.startsOn, fromUtcMillis(111));
    });

    test('逗号串里的垃圾片段丢掉，能读的照读', () async {
      await db
          .into(db.recurrenceRules)
          .insert(
            database.RecurrenceRulesCompanion.insert(
              id: 'messy',
              frequency: RecurrenceFrequency.weekly,
              startsOn: const Value<int>(111),
              byWeekday: const Value<String>('1, x, 3,,'),
              createdAt: 111,
            ),
          );
      await link(taskId, 'messy');

      expect((await recurrence.findForTask(taskId))!.byWeekday, <int>{1, 3});
    });
  });
}
