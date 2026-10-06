import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/constants/app_constants.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/models/task_query.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() async {
    db = createTestDatabase();
    repo = TaskRepository(db);
    await db.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<TodoTask>> list([TaskQuery query = const TaskQuery()]) {
    return repo.watch(query).first;
  }

  Future<List<String>> titles([TaskQuery query = const TaskQuery()]) async {
    final List<TodoTask> items = await list(query);
    return items.map((TodoTask task) => task.title).toList();
  }

  group('读写基本字段', () {
    test('新建后能原样读回来', () async {
      final int due = dayOnlyMillis(DateTime(2026, 10, 8));
      final String id = await repo.create(
        title: '写周报',
        note: '周四之前',
        dueDate: due,
        priority: TaskPriority.high,
      );

      final TodoTask? task = await repo.findById(id);

      expect(task, isNotNull);
      expect(task!.title, '写周报');
      expect(task.note, '周四之前');
      expect(task.dueDate, due);
      expect(task.dueDateHasTime, isFalse);
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.isCompleted, isFalse);
      expect(task.subtaskTotal, 0);
      expect(task.tagNames, isEmpty);
    });

    test('查不存在的 id 返回 null，不是抛异常', () async {
      expect(await repo.findById('没有这个 id'), isNull);
    });

    test('标题两端空白被去掉', () async {
      final String id = await repo.create(title: '  写周报  ');

      expect((await repo.findById(id))!.title, '写周报');
    });

    test('update 是整体覆盖，能把备注清成 null', () async {
      final String id = await repo.create(title: '写周报', note: '旧备注');

      await repo.update(
        id,
        title: '写月报',
        note: null,
        dueDate: null,
        dueDateHasTime: false,
        priority: TaskPriority.low,
        listId: null,
        recurrenceRuleId: null,
      );

      final TodoTask task = (await repo.findById(id))!;
      expect(task.title, '写月报');
      expect(task.note, isNull);
      expect(task.dueDate, isNull);
      expect(task.priority, TaskPriority.low);
    });
  });

  group('完成状态', () {
    test('默认不返回已完成的，打开开关才返回', () async {
      await repo.create(title: '待办');
      final String done = await repo.create(title: '做完了');
      await repo.setCompleted(done, true);

      expect(await titles(), <String>['待办']);
      expect(
        (await titles(const TaskQuery(showCompleted: true))).toSet(),
        <String>{'待办', '做完了'},
      );
    });

    test('完成时记下时间，取消时清掉', () async {
      final String id = await repo.create(title: '做完了');

      await repo.setCompleted(id, true);
      final TodoTask completed = (await repo.findById(id))!;
      expect(completed.status, TaskStatus.completed);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      await repo.setCompleted(id, false);
      final TodoTask reopened = (await repo.findById(id))!;
      expect(reopened.status, TaskStatus.pending);
      expect(reopened.completedAt, isNull);
    });

    test('deleteCompleted 只删已完成的，并返回条数', () async {
      await repo.create(title: '留着');
      final String a = await repo.create(title: '删我 1');
      final String b = await repo.create(title: '删我 2');
      await repo.setCompleted(a, true);
      await repo.setCompleted(b, true);

      expect(await repo.deleteCompleted(), 2);
      expect(await titles(const TaskQuery(showCompleted: true)), <String>[
        '留着',
      ]);
    });

    test('未完成任务数只数未完成的', () async {
      await repo.create(title: 'A');
      final String b = await repo.create(title: 'B');
      await repo.setCompleted(b, true);

      expect(await repo.watchPendingCount().first, 1);
    });
  });

  group('删除与撤销', () {
    test('删掉之后查不到', () async {
      final String id = await repo.create(title: '临时');
      await repo.delete(id);

      expect(await repo.findById(id), isNull);
      expect(await titles(), isEmpty);
    });

    test('撤销时连 id、创建时间和标签一起还原', () async {
      final String id = await repo.create(title: '写周报');
      await repo.setTaskTags(id, <String>['工作']);
      final TodoTask before = (await repo.findById(id))!;

      await repo.delete(id);
      expect(await repo.findById(id), isNull);

      expect(await repo.restore(before), isTrue);

      final TodoTask after = (await repo.findById(id))!;
      expect(after.id, before.id);
      expect(after.title, before.title);
      expect(after.createdAt, before.createdAt);
      expect(after.tagNames, <String>['工作']);
    });

    test('id 还在时撤销不会覆盖已有数据', () async {
      final String id = await repo.create(title: '原样');
      final TodoTask stale = (await repo.findById(id))!.copyWith(title: '改过的');

      expect(await repo.restore(stale), isFalse);
      expect((await repo.findById(id))!.title, '原样');
    });
  });

  group('子任务', () {
    test('子任务计入完成进度', () async {
      final String id = await repo.create(title: '搬家');
      final String packed = await repo.addSubtask(id, '打包');
      await repo.addSubtask(id, '叫车');

      TodoTask task = (await repo.findById(id))!;
      expect(task.subtaskTotal, 2);
      expect(task.subtaskDone, 0);

      await repo.setSubtaskDone(packed, true);
      task = (await repo.findById(id))!;
      expect(task.subtaskDone, 1);
    });

    test('子任务按加入顺序排列，改名时去空白', () async {
      final String id = await repo.create(title: '搬家');
      await repo.addSubtask(id, '打包');
      final String second = await repo.addSubtask(id, '  叫车  ');

      final List<TodoSubtask> items = await repo.watchSubtasks(id).first;
      expect(items.map((TodoSubtask s) => s.title), <String>['打包', '叫车']);
      expect(items.map((TodoSubtask s) => s.sortOrder), <int>[0, 1]);

      await repo.renameSubtask(second, '  约车  ');
      final List<TodoSubtask> renamed = await repo.watchSubtasks(id).first;
      expect(renamed.last.title, '约车');
    });

    test('删掉子任务后进度会退回来', () async {
      final String id = await repo.create(title: '搬家');
      final String packed = await repo.addSubtask(id, '打包');
      await repo.setSubtaskDone(packed, true);
      await repo.deleteSubtask(packed);

      final TodoTask task = (await repo.findById(id))!;
      expect(task.subtaskTotal, 0);
      expect(task.subtaskDone, 0);
    });

    test('删掉任务会把子任务一起带走', () async {
      final String id = await repo.create(title: '搬家');
      await repo.addSubtask(id, '打包');
      await repo.delete(id);

      expect(await repo.watchSubtasks(id).first, isEmpty);
    });

    test('重排之后读回来的顺序就是传进去的顺序', () async {
      final String id = await repo.create(title: '搬家');
      final String packed = await repo.addSubtask(id, '打包');
      final String car = await repo.addSubtask(id, '叫车');
      final String key = await repo.addSubtask(id, '取钥匙');

      await repo.reorderSubtasks(<String>[key, packed, car]);

      final List<TodoSubtask> items = await repo.watchSubtasks(id).first;
      expect(items.map((TodoSubtask s) => s.title), <String>[
        '取钥匙',
        '打包',
        '叫车',
      ]);
      expect(items.map((TodoSubtask s) => s.sortOrder), <int>[0, 1, 2]);
    });

    test('往末尾追加的子任务还是排在最后', () async {
      final String id = await repo.create(title: '搬家');
      final String packed = await repo.addSubtask(id, '打包');
      final String car = await repo.addSubtask(id, '叫车');

      await repo.reorderSubtasks(<String>[car, packed]);
      await repo.addSubtask(id, '锁门');

      final List<TodoSubtask> items = await repo.watchSubtasks(id).first;
      expect(items.map((TodoSubtask s) => s.title), <String>['叫车', '打包', '锁门']);
    });

    test('空列表什么都不做', () async {
      final String id = await repo.create(title: '搬家');
      await repo.addSubtask(id, '打包');

      await repo.reorderSubtasks(const <String>[]);

      expect(await repo.watchSubtasks(id).first, hasLength(1));
    });
  });

  group('标签', () {
    test('标签会去空白、去重，并按名字排序返回', () async {
      final String id = await repo.create(title: '写周报');
      await repo.setTaskTags(id, <String>['  工作 ', '工作', '', '紧急']);

      expect((await repo.findById(id))!.tagNames, <String>['工作', '紧急']);
    });

    test('按标签筛选任务', () async {
      final String id = await repo.create(title: '写周报');
      await repo.create(title: '买菜');
      await repo.setTaskTags(id, <String>['工作']);

      expect(await titles(const TaskQuery(tagName: '工作')), <String>['写周报']);
      expect(await titles(const TaskQuery(tagName: '没有这个标签')), isEmpty);
    });

    test('重设标签是整体替换', () async {
      final String id = await repo.create(title: '写周报');
      await repo.setTaskTags(id, <String>['工作', '紧急']);
      await repo.setTaskTags(id, <String>['紧急']);

      expect((await repo.findById(id))!.tagNames, <String>['紧急']);
    });

    test('两个任务可以共用同一个标签', () async {
      final String a = await repo.create(title: 'A');
      final String b = await repo.create(title: 'B');
      await repo.setTaskTags(a, <String>['工作']);
      await repo.setTaskTags(b, <String>['工作']);

      expect((await repo.findById(a))!.tagNames, <String>['工作']);
      expect((await repo.findById(b))!.tagNames, <String>['工作']);
    });

    test('删掉任务会把标签关联一起带走，标签本身还在', () async {
      final String id = await repo.create(title: '写周报');
      await repo.setTaskTags(id, <String>['工作']);
      expect(await db.select(db.taskTags).get(), hasLength(1));

      await repo.delete(id);

      expect(
        await db.select(db.taskTags).get(),
        isEmpty,
        reason: 'task_tags.task_id 是 ON DELETE CASCADE',
      );
      expect(
        await db.select(db.tags).get(),
        hasLength(1),
        reason: '标签是跨任务共用的，任务没了不该顺手把它删掉',
      );
    });
  });

  group('搜索', () {
    test('标题和备注都能命中，且不分大小写', () async {
      final String id = await repo.create(title: 'Write Report');
      await repo.create(title: '买菜');
      await repo.update(
        id,
        title: 'Write Report',
        note: '周报要点',
        dueDate: null,
        dueDateHasTime: false,
        priority: TaskPriority.none,
        listId: null,
        recurrenceRuleId: null,
      );

      expect(await titles(const TaskQuery(searchText: 'report')), <String>[
        'Write Report',
      ]);
      expect(await titles(const TaskQuery(searchText: '周报')), <String>[
        'Write Report',
      ]);
      expect(await titles(const TaskQuery(searchText: '不存在')), isEmpty);
    });

    test('搜索里的 % 当字面量，不会变成通配符', () async {
      await repo.create(title: '打折 100%');
      await repo.create(title: '无关');

      expect(await titles(const TaskQuery(searchText: '%')), <String>[
        '打折 100%',
      ]);
    });
  });

  group('筛选', () {
    test('只看今天的', () async {
      final DateTime now = DateTime.now();
      await repo.create(title: '今天的', dueDate: dayOnlyMillis(now));
      await repo.create(
        title: '昨天的',
        dueDate: dayOnlyMillis(now.subtract(const Duration(days: 1))),
      );
      await repo.create(title: '没日期的');

      expect(await titles(const TaskQuery(dueTodayOnly: true)), <String>[
        '今天的',
      ]);
    });

    test('只看逾期的', () async {
      final DateTime now = DateTime.now();
      await repo.create(
        title: '逾期了',
        dueDate: dayOnlyMillis(now.subtract(const Duration(days: 1))),
      );
      await repo.create(title: '没日期的');

      expect(await titles(const TaskQuery(overdueOnly: true)), <String>['逾期了']);
    });

    test('按清单筛选', () async {
      await repo.create(title: '收件箱里的', listId: AppConstants.inboxListId);
      await repo.create(title: '没进清单的');

      expect(
        await titles(const TaskQuery(listId: AppConstants.inboxListId)),
        <String>['收件箱里的'],
      );
      expect(await titles(const TaskQuery(listId: '根本没有这个清单')), isEmpty);
    });

    test('按优先级筛选', () async {
      await repo.create(title: '高', priority: TaskPriority.high);
      await repo.create(title: '低', priority: TaskPriority.low);

      expect(
        await titles(
          const TaskQuery(priorities: <TaskPriority>{TaskPriority.high}),
        ),
        <String>['高'],
      );
    });
  });

  group('排序', () {
    test('默认按截止时间，没日期的排最后', () async {
      await repo.create(title: '没日期');
      await repo.create(
        title: '后天',
        dueDate: dayOnlyMillis(DateTime(2026, 5, 3)),
      );
      await repo.create(
        title: '明天',
        dueDate: dayOnlyMillis(DateTime(2026, 5, 2)),
      );

      expect(await titles(), <String>['明天', '后天', '没日期']);
    });

    test('按优先级从高到低', () async {
      await repo.create(title: '低', priority: TaskPriority.low);
      await repo.create(title: '高', priority: TaskPriority.high);
      await repo.create(title: '没定');

      expect(await titles(const TaskQuery(sort: TaskSort.priority)), <String>[
        '高',
        '低',
        '没定',
      ]);
    });

    test('按标题排，不分大小写', () async {
      await repo.create(title: 'banana');
      await repo.create(title: 'Apple');

      expect(await titles(const TaskQuery(sort: TaskSort.title)), <String>[
        'Apple',
        'banana',
      ]);
    });
  });

  test('watchSingle 会推送后来的修改', () async {
    final String id = await repo.create(title: '写周报');
    final List<TodoTask?> seen = <TodoTask?>[];
    final StreamSubscription<TodoTask?> subscription = repo
        .watchSingle(id)
        .listen(seen.add);
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    expect(seen.last?.title, '写周报');

    await repo.update(
      id,
      title: '写月报',
      note: null,
      dueDate: null,
      dueDateHasTime: false,
      priority: TaskPriority.none,
      listId: null,
      recurrenceRuleId: null,
    );
    await pumpEventQueue();
    expect(seen.last?.title, '写月报');
  });
}
