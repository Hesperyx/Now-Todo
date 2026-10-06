import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/constants/app_constants.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ListRepository lists;
  late TagRepository tags;
  late TaskRepository tasks;

  setUp(() async {
    db = createTestDatabase();
    lists = ListRepository(db);
    tags = TagRepository(db);
    tasks = TaskRepository(db);
    await db.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  group('清单', () {
    test('初始化之后有一个内置收件箱', () async {
      final List<TodoList> all = await lists.watch().first;

      expect(all, hasLength(1));
      expect(all.single.id, AppConstants.inboxListId);
      expect(all.single.name, '收件箱');
      expect(all.single.isBuiltIn, isTrue);
    });

    test('新建的清单排在最后', () async {
      await lists.create('工作');
      await lists.create('家里');

      final List<TodoList> all = await lists.watch().first;
      expect(all.map((TodoList list) => list.name), <String>[
        '收件箱',
        '工作',
        '家里',
      ]);
    });

    test('改名', () async {
      final String id = await lists.create('工作');
      await lists.rename(id, '项目');

      final List<TodoList> all = await lists.watch().first;
      expect(all.last.name, '项目');
    });

    test('内置清单删不掉', () async {
      expect(await lists.delete(AppConstants.inboxListId), isFalse);
      expect(await lists.watch().first, hasLength(1));
    });

    test('删掉清单以后，里面的任务回到未分类而不是被一起删掉', () async {
      final String listId = await lists.create('临时');
      final String taskId = await tasks.create(title: '搬家', listId: listId);

      expect(await lists.delete(listId), isTrue);

      final TodoTask? task = await tasks.findById(taskId);
      expect(task, isNotNull);
      expect(task!.listId, isNull);
    });

    test('未完成任务数只数这个清单里没完成的', () async {
      final String listId = await lists.create('工作');
      final String a = await tasks.create(title: 'A', listId: listId);
      await tasks.create(title: 'B', listId: listId);
      await tasks.create(title: '别的清单的');
      await tasks.setCompleted(a, true);

      final List<TodoList> all = await lists.watch().first;
      final TodoList work = all.firstWhere((TodoList l) => l.id == listId);
      expect(work.pendingCount, 1);
    });

    test('reorder 按给进来的顺序重排', () async {
      final String a = await lists.create('A');
      final String b = await lists.create('B');

      await lists.reorder(<String>[b, a]);

      final List<TodoList> all = await lists.watch().first;
      final List<String> custom = all
          .where((TodoList list) => !list.isBuiltIn)
          .map((TodoList list) => list.name)
          .toList();
      expect(custom, <String>['B', 'A']);
    });
  });

  group('标签', () {
    test('标签跟着任务出现，并统计被几个任务用到', () async {
      final String a = await tasks.create(title: 'A');
      final String b = await tasks.create(title: 'B');
      await tasks.setTaskTags(a, <String>['urgent', 'work']);
      await tasks.setTaskTags(b, <String>['work']);

      final List<TodoTag> all = await tags.watch().first;
      expect(all.map((TodoTag tag) => tag.name), <String>['urgent', 'work']);

      final TodoTag work = all.firstWhere((TodoTag tag) => tag.name == 'work');
      expect(work.taskCount, 2);
    });

    test('摘掉标签以后引用数归零，但标签本身还在', () async {
      final String id = await tasks.create(title: 'A');
      await tasks.setTaskTags(id, <String>['work']);
      await tasks.setTaskTags(id, <String>[]);

      final List<TodoTag> all = await tags.watch().first;
      expect(all, hasLength(1));
      expect(all.single.taskCount, 0);
    });

    test('改名和设颜色', () async {
      final String id = await tasks.create(title: 'A');
      await tasks.setTaskTags(id, <String>['work']);

      final TodoTag tag = (await tags.watch().first).single;
      await tags.rename(tag.id, 'job');
      await tags.setColor(tag.id, 0xFF00FF00);

      final TodoTag updated = (await tags.watch().first).single;
      expect(updated.name, 'job');
      expect(updated.color, 0xFF00FF00);
    });

    test('删掉标签会连同任务关联一起清掉，但任务还在', () async {
      final String id = await tasks.create(title: 'A');
      await tasks.setTaskTags(id, <String>['work']);

      final TodoTag tag = (await tags.watch().first).single;
      await tags.delete(tag.id);

      expect(await tags.watch().first, isEmpty);
      final TodoTask task = (await tasks.findById(id))!;
      expect(task.tagNames, isEmpty);
      expect(task.title, 'A');
    });

    test('从标签管理页新建：是一个没有任何任务引用的标签', () async {
      final String id = await tags.create('urgent', color: 0xFFB0475A);

      final List<TodoTag> all = await tags.watch().first;
      expect(all, hasLength(1));
      expect(all.single.id, id);
      expect(all.single.name, 'urgent');
      expect(all.single.color, 0xFFB0475A);
      expect(all.single.taskCount, 0);
    });

    test('新建时首尾空白会去掉', () async {
      await tags.create('  work  ');

      expect((await tags.watch().first).single.name, 'work');
    });

    test('新建一个已经存在的标签，复用已有的那条', () async {
      final String first = await tags.create('work');
      final String second = await tags.create('work');

      expect(second, first);
      expect(await tags.watch().first, hasLength(1));
    });

    test('大小写不同算两个标签，与唯一索引的语义一致', () async {
      await tags.create('work');
      await tags.create('Work');

      // 排序用的是 `COLLATE NOCASE`，这两个名字在它眼里相等，
      // 所以谁先谁后不确定，这里只比集合。
      expect(
        (await tags.watch().first).map((TodoTag tag) => tag.name).toSet(),
        <String>{'work', 'Work'},
      );
    });

    test('管理页建的标签，任务里直接写同名标签会用上同一条', () async {
      final String created = await tags.create('work');
      final String taskId = await tasks.create(title: 'A');
      await tasks.setTaskTags(taskId, <String>['work']);

      final List<TodoTag> all = await tags.watch().first;
      expect(all, hasLength(1));
      expect(all.single.id, created);
      expect(all.single.taskCount, 1);
    });
  });
}
