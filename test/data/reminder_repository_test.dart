import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/notifications/reminder_plan.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/reminder_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReminderRepository reminders;
  late TaskRepository tasks;
  late String taskId;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    reminders = ReminderRepository(db);
    tasks = TaskRepository(db);
    taskId = await tasks.create(title: '交周报');
  });

  tearDown(() async {
    await db.close();
  });

  /// 造一个「未来某刻」的 UTC 毫秒值，避免用例依赖真实时间。
  int at(int year, int month, int day, [int hour = 9]) =>
      DateTime(year, month, day, hour).utcMillis;

  group('新增与读取', () {
    test('新增之后读得回来，字段都在', () async {
      final String id = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 1),
      );

      final List<TodoReminder> list = await reminders.listForTask(taskId);
      expect(list, hasLength(1));
      expect(list.single.id, id);
      expect(list.single.taskId, taskId);
      expect(list.single.remindAt, at(2030, 5, 1));
      expect(list.single.enabled, isTrue);
    });

    test('默认是「仅一次」', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));
      final List<TodoReminder> list = await reminders.listForTask(taskId);
      expect(list.single.repeatType, ReminderRepeatType.once);
    });

    test('按触发时刻升序返回，不按插入顺序', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 10));
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 5));

      final List<TodoReminder> list = await reminders.listForTask(taskId);
      expect(list.map((TodoReminder r) => r.remindAt).toList(), <int>[
        at(2030, 5, 1),
        at(2030, 5, 5),
        at(2030, 5, 10),
      ]);
    });

    test('一个任务可以有多条提醒，别的任务的读不到', () async {
      final String other = await tasks.create(title: '买菜');
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 2));
      await reminders.add(taskId: other, remindAt: at(2030, 5, 3));

      expect(await reminders.listForTask(taskId), hasLength(2));
      expect(await reminders.listForTask(other), hasLength(1));
    });

    test('watchForTask 会推出新值', () async {
      final Stream<List<TodoReminder>> stream = reminders.watchForTask(taskId);
      final List<List<TodoReminder>> emissions = <List<TodoReminder>>[];
      final StreamSubscription<List<TodoReminder>> sub = stream.listen(
        emissions.add,
      );

      await pumpEventQueue();
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));
      await pumpEventQueue();

      expect(emissions.first, isEmpty);
      expect(emissions.last, hasLength(1));

      await sub.cancel();
    });
  });

  group('修改与删除', () {
    test('只改传进来的字段，其余不动', () async {
      final String id = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 1),
        repeatType: ReminderRepeatType.weekly,
      );

      await reminders.update(id, remindAt: at(2030, 6, 1));

      final TodoReminder row = (await reminders.listForTask(taskId)).single;
      expect(row.remindAt, at(2030, 6, 1));
      // 这两个没传，必须原样保留。
      expect(row.repeatType, ReminderRepeatType.weekly);
      expect(row.enabled, isTrue);
    });

    test('可以关掉再打开，记录本身不删', () async {
      final String id = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 1),
      );

      await reminders.update(id, enabled: false);
      expect((await reminders.listForTask(taskId)).single.enabled, isFalse);

      await reminders.update(id, enabled: true);
      expect((await reminders.listForTask(taskId)).single.enabled, isTrue);
    });

    test('删除只删指定的那一条', () async {
      final String keep = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 1),
      );
      final String drop = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 2),
      );

      await reminders.delete(drop);

      final List<TodoReminder> list = await reminders.listForTask(taskId);
      expect(list, hasLength(1));
      expect(list.single.id, keep);
    });
  });

  group('排程用的数据源', () {
    test('带上任务标题与未完成状态', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));

      final List<ReminderSource> sources = await reminders.watchSources().first;

      expect(sources, hasLength(1));
      expect(sources.single.taskTitle, '交周报');
      expect(sources.single.taskCompleted, isFalse);
    });

    test('任务被勾完成之后，同一批数据里的 taskCompleted 会跟着变', () async {
      final String id = await reminders.add(
        taskId: taskId,
        remindAt: at(2030, 5, 1),
      );
      await tasks.setCompleted(taskId, true);

      final List<ReminderSource> sources = await reminders.watchSources().first;

      expect(sources.single.id, id);
      // 调度器靠这个字段决定「不排但保留」。
      expect(sources.single.taskCompleted, isTrue);
    });

    test('任务改名之后，标题会重新发射', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));

      final List<String> titles = <String>[];
      final StreamSubscription<List<ReminderSource>> sub = reminders
          .watchSources()
          .listen(
            (List<ReminderSource> list) => titles.add(list.single.taskTitle),
          );

      await pumpEventQueue();
      await tasks.update(
        taskId,
        title: '交月报',
        note: null,
        dueDate: null,
        dueDateHasTime: false,
        priority: TaskPriority.none,
        listId: null,
        recurrenceRuleId: null,
      );
      await pumpEventQueue();

      expect(titles.first, '交周报');
      expect(titles.last, '交月报');

      await sub.cancel();
    });

    test('任务被删掉时，它的提醒也一起没了', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));
      expect(await reminders.listForTask(taskId), hasLength(1));

      await tasks.delete(taskId);

      // 靠 `ON DELETE CASCADE`，不是靠应用层清理。这条断言同时验证了
      // `PRAGMA foreign_keys = ON` 在新表上依然生效——外键没开的话
      // 这里会留下一条指向不存在任务的孤儿提醒，而调度器会一直试着排它。
      expect(await reminders.listForTask(taskId), isEmpty);
      expect(await reminders.watchSources().first, isEmpty);
    });

    test('多条提醒按触发时刻升序', () async {
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 3));
      await reminders.add(taskId: taskId, remindAt: at(2030, 5, 1));

      final List<ReminderSource> sources = await reminders.watchSources().first;

      expect(sources.first.remindAt, at(2030, 5, 1));
      expect(sources.last.remindAt, at(2030, 5, 3));
    });
  });
}
