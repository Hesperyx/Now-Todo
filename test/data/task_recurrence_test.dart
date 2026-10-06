import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart' as database;
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/recurrence_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

/// 「完成一条重复任务，生成下一条」这条链路。
///
/// 这里断言的都是**下一条任务本身**长什么样——日期序列怎么算在
/// `test/core/recurrence/` 里，这一层关心的是复制了哪些字段、什么时候不生成。
void main() {
  late database.AppDatabase db;
  late TaskRepository tasks;
  late RecurrenceRepository recurrence;
  late ListRepository lists;
  late String ruleId;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    tasks = TaskRepository(db);
    recurrence = RecurrenceRepository(db);
    lists = ListRepository(db);
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

  /// 造一条带规则的任务，返回任务 id。
  Future<String> seed(
    RecurrenceRule r, {
    String title = '交周报',
    String? note,
    TaskPriority priority = TaskPriority.none,
    int? dueDate,
    bool dueDateHasTime = false,
    String? listId,
  }) async {
    ruleId = await recurrence.create(r);
    return tasks.create(
      title: title,
      note: note,
      priority: priority,
      dueDate: dueDate,
      dueDateHasTime: dueDateHasTime,
      listId: listId,
      recurrenceRuleId: ruleId,
    );
  }

  Future<int> taskCount() async => (await db.select(db.tasks).get()).length;

  Future<TodoTask> completeAndReadNext(
    String id, {
    bool completed = true,
  }) async {
    final String? nextId = await tasks.setCompleted(id, completed);
    expect(nextId, isNotNull, reason: '这一步应该生出下一条');
    return (await tasks.findById(nextId!))!;
  }

  group('完成后生成下一条', () {
    test('每天 09:30 的系列，下一条也是 09:30', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1, 9, 30)),
        dueDate: d(2030, 1, 1, 9, 30).utcMillis,
        dueDateHasTime: true,
      );

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, d(2030, 1, 2, 9, 30).utcMillis);
      expect(next.dueDateHasTime, isTrue);
      expect(next.title, '交周报');
      expect(next.recurrenceRuleId, ruleId);
      expect(next.status, TaskStatus.pending, reason: '新的一条是未完成的');
      expect(next.completedAt, isNull);
      expect(await taskCount(), 2);
    });

    test('日期化的任务生成的下一条是本地零点', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, dayOnlyMillis(d(2030, 1, 2)));
      expect(next.dueDateHasTime, isFalse);
    });

    test('标题、备注、优先级、清单、标签都跟着走，子任务不跟着走', () async {
      final String listId = await lists.create('工作');
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        note: '带上月报',
        priority: TaskPriority.high,
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
        listId: listId,
      );
      await tasks.setTaskTags(id, <String>['工作', '重要']);
      await tasks.addSubtask(id, '写摘要');

      final TodoTask next = await completeAndReadNext(id);

      expect(next.note, '带上月报');
      expect(next.priority, TaskPriority.high);
      expect(next.listId, listId);
      expect(next.tagNames, unorderedEquals(<String>['工作', '重要']));
      expect(
        await tasks.watchSubtasks(next.id).first,
        isEmpty,
        reason: '子任务是这一条自己的清单，不是系列的属性',
      );
      expect(await tasks.watchSubtasks(id).first, hasLength(1));
    });

    test('重复点两次完成不会生出两条', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      expect(await tasks.setCompleted(id, true), isNotNull);
      expect(await tasks.setCompleted(id, true), isNull);
      expect(await taskCount(), 2);
    });

    test('取消完成不会生成', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      expect(await tasks.setCompleted(id, false), isNull);
      expect(await taskCount(), 1);
      expect((await tasks.findById(id))!.status, TaskStatus.pending);
    });

    test('没有规则的任务，完成就是完成', () async {
      final String id = await tasks.create(title: '买牛奶');

      expect(await tasks.setCompleted(id, true), isNull);
      expect(await taskCount(), 1);
      expect((await tasks.findById(id))!.status, TaskStatus.completed);
    });

    test('结束日期到了就停：最后一条完成后没有下一条', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1), endDate: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      expect(await tasks.setCompleted(id, true), isNull);
      expect(await taskCount(), 1);
    });

    test('次数没用完就继续', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1), endCount: 3),
        dueDate: dayOnlyMillis(d(2030, 1, 3)),
      );
      // 系列里已经有三条中的两条（这一条 + 一条历史），所以还剩一次。
      ruleId = (await tasks.findById(id))!.recurrenceRuleId!;
      await tasks.create(
        title: '交周报',
        dueDate: dayOnlyMillis(d(2030, 1, 2)),
        recurrenceRuleId: ruleId,
      );

      final TodoTask next = await completeAndReadNext(id);
      expect(next.dueDate, dayOnlyMillis(d(2030, 1, 4)));
    });

    test('次数用完了就停：共 3 次', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1), endCount: 3),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );
      ruleId = (await tasks.findById(id))!.recurrenceRuleId!;
      await tasks.create(
        title: '交周报',
        dueDate: dayOnlyMillis(d(2030, 1, 2)),
        recurrenceRuleId: ruleId,
      );
      await tasks.create(
        title: '交周报',
        dueDate: dayOnlyMillis(d(2030, 1, 3)),
        recurrenceRuleId: ruleId,
      );

      expect(await tasks.setCompleted(id, true), isNull);
      expect(await taskCount(), 3);
    });

    test('拖了很久才完成：不会生成一条一出生就逾期的任务', () async {
      // 锚点在过去，所以有一串日期已经在 now 之前了。
      final int start = dayOnlyMillis(
        DateTime.now().subtract(const Duration(days: 5)),
      );
      final String id = await seed(
        rule(startsOn: fromUtcMillis(start)),
        dueDate: start,
      );

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, dayOnlyMillis(DateTime.now()));
    });

    test('被单独挪过日期的实例，完成后回到原来的节奏', () async {
      // 2030-01-07 是周一；这一条被挪到了周三 01-16。
      final String id = await seed(
        rule(
          startsOn: d(2030, 1, 7),
          frequency: RecurrenceFrequency.weekly,
          byWeekday: <int>{1},
        ),
        dueDate: dayOnlyMillis(d(2030, 1, 16)),
      );

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, dayOnlyMillis(d(2030, 1, 21)), reason: '下一个周一');
    });

    test('下一条还在同一个系列里，可以一路做下去', () async {
      final String first = await seed(
        rule(startsOn: d(2030, 2, 1)),
        dueDate: dayOnlyMillis(d(2030, 2, 1)),
      );

      final TodoTask second = await completeAndReadNext(first);
      final TodoTask third = await completeAndReadNext(second.id);

      expect(second.dueDate, dayOnlyMillis(d(2030, 2, 2)));
      expect(third.dueDate, dayOnlyMillis(d(2030, 2, 3)));
      expect(third.recurrenceRuleId, ruleId);
      expect(await taskCount(), 3);
    });

    test('把重复关掉之后，完成不再生成', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );
      await tasks.update(
        id,
        title: '交周报',
        note: null,
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
        dueDateHasTime: false,
        priority: TaskPriority.none,
        listId: null,
        recurrenceRuleId: null,
      );

      expect(await tasks.setCompleted(id, true), isNull);
      expect(await taskCount(), 1);
    });

    test('生成下一条和标记完成在同一个事务里', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      await tasks.setCompleted(id, true);

      final TodoTask done = (await tasks.findById(id))!;
      expect(done.status, TaskStatus.completed);
      expect(done.completedAt, isNotNull);
      expect(await taskCount(), 2);
    });
  });

  group('规则与实例的关系', () {
    test('删掉规则，历史实例还在，只是不再是一个系列', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );

      await recurrence.delete(ruleId);

      final TodoTask? after = await tasks.findById(id);
      expect(after, isNotNull);
      expect(after!.recurrenceRuleId, isNull);
      expect(await recurrence.findForTask(id), isNull);
      expect(await tasks.setCompleted(id, true), isNull, reason: '没有规则就不生');
    });

    test('删掉任务不会连带删掉规则行（同系列还有别的实例）', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );
      final String sibling = await tasks.create(
        title: '交周报',
        dueDate: dayOnlyMillis(d(2030, 1, 2)),
        recurrenceRuleId: ruleId,
      );

      await tasks.delete(id);

      expect(await tasks.findById(id), isNull);
      expect(
        (await recurrence.findForTask(sibling))!.startsOn,
        d(2030, 1, 1),
        reason: '规则还归另一条实例用',
      );
    });

    test('生成下一条用的是规则自己的锚点，不是这条实例的日期', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );
      // 谁也没把这一条的日期改掉，但规则锚点被改成了 02-01（「此后全部」的效果）。
      await recurrence.update(ruleId, rule(startsOn: d(2030, 2, 1)));

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, dayOnlyMillis(d(2030, 2, 2)));
    });

    test('同系列还有别的未完成实例时，完成其中一条照样生成下一条', () async {
      final String id = await seed(
        rule(startsOn: d(2030, 1, 1)),
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
      );
      final String sibling = await tasks.create(
        title: '交周报',
        dueDate: dayOnlyMillis(d(2030, 1, 1)),
        recurrenceRuleId: ruleId,
      );

      final TodoTask next = await completeAndReadNext(id);

      expect(next.dueDate, dayOnlyMillis(d(2030, 1, 2)));
      expect((await tasks.findById(sibling))!.status, TaskStatus.pending);
    });
  });
}
