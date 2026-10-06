import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/models/task_query.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

/// 1000 条任务下的搜索压测。
///
/// 这一条对应 `docs/MILESTONES.md` 里那句「搜索在 1000 条任务下无明显卡顿」。
/// 要说明的是它测的**不是**「在真机上多久出结果」——这里是内存库和开发机。
/// 它能抓住的是量级错误：O(n²) 的匹配、每条都开一次查询、忘了加索引之类的
/// 写法会立刻从这个数字上跳出来。真机手感只能上手试。
///
/// 这里直接在仓储层跑，不经过界面：卡顿的一个大头确实是界面，但那是
/// `ListView.builder` 的事，而列表本来就是懒加载的。
void main() {
  late AppDatabase db;
  late TaskRepository tasks;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    tasks = TaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 造 [count] 条任务，每 10 条里有一条标题带「周报」，每 3 条里有一条带备注。
  Future<void> seed(int count) async {
    await db.transaction(() async {
      for (int i = 0; i < count; i++) {
        await tasks.create(
          title: i % 10 == 0 ? '写第 $i 份周报' : '第 $i 件事',
          note: i % 3 == 0 ? '备注里也写一遍：第 $i 件事' : null,
          priority: TaskPriority.values[i % TaskPriority.values.length],
        );
      }
    });
  }

  test('1000 条任务下，搜索只返回匹配的那些', () async {
    await seed(1000);

    final List<TodoTask> hits = await tasks
        .watch(const TaskQuery(searchText: '周报'))
        .first;

    expect(hits, hasLength(100));
    for (final TodoTask task in hits) {
      expect(task.title, contains('周报'));
    }
  });

  test('备注也会被搜到，不是只看标题', () async {
    await seed(1000);

    final List<TodoTask> hits = await tasks
        .watch(const TaskQuery(searchText: '备注里也写一遍'))
        .first;

    // 0、3、6……999 共 334 条。
    expect(hits, hasLength(334));
  });

  test('搜索词里的 % 与 _ 是普通字符，不是通配符', () async {
    await tasks.create(title: '100% 完成');
    await tasks.create(title: '1000 完成');
    await tasks.create(title: 'a_b');
    await tasks.create(title: 'axb');

    final List<TodoTask> percent = await tasks
        .watch(const TaskQuery(searchText: '100%'))
        .first;
    expect(percent.map((TodoTask task) => task.title), <String>['100% 完成']);

    final List<TodoTask> underscore = await tasks
        .watch(const TaskQuery(searchText: 'a_b'))
        .first;
    expect(underscore.map((TodoTask task) => task.title), <String>['a_b']);
  });

  test('1000 条任务下，搜索耗时在可接受范围', () async {
    await seed(1000);

    // 先热一遍：第一次要建查询流、编译语句，那不是用户每次输入都要付的代价。
    await tasks.watch(const TaskQuery(searchText: '周报')).first;

    final List<int> millis = <int>[];
    for (final String text in <String>['周', '周报', '第 9 件事', '找不到的词']) {
      final Stopwatch sw = Stopwatch()..start();
      final List<TodoTask> hits = await tasks
          .watch(TaskQuery(searchText: text))
          .first;
      sw.stop();
      millis.add(sw.elapsedMilliseconds);
      debugPrint(
        '[搜索压测] 「$text」命中 ${hits.length} 条，${sw.elapsedMilliseconds}ms',
      );
    }

    // 领头的通配符让这个查询注定是全表扫描，1000 行也就是一次内存扫描的量级。
    // 阈值给得宽：这条断言要抓的是「多了个十倍」这种量级错误，不是抖动。
    expect(millis.reduce((int a, int b) => a > b ? a : b), lessThan(300));
  });
}
