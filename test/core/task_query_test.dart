import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/models/task_query.dart';

void main() {
  test('默认只看未完成的任务', () {
    expect(const TaskQuery().showCompleted, isFalse);
  });

  test('normalizedSearch 把纯空白当成没有搜索', () {
    expect(const TaskQuery().normalizedSearch, isNull);
    expect(const TaskQuery(searchText: '   ').normalizedSearch, isNull);
    expect(const TaskQuery(searchText: ' 周报 ').normalizedSearch, '周报');
  });

  test('copyWith 能区分「不改」和「改成 null」', () {
    const TaskQuery query = TaskQuery(
      listId: 'l1',
      tagName: '工作',
      searchText: '周报',
    );

    expect(query.copyWith().listId, 'l1');
    expect(query.copyWith(listId: null).listId, isNull);
    // 只清清单，标签要留着。
    expect(query.copyWith(listId: null).tagName, '工作');
    expect(query.copyWith(searchText: null).searchText, isNull);
    expect(query.copyWith(searchText: null).tagName, '工作');
  });

  test('优先级集合比内容不比顺序', () {
    const TaskQuery a = TaskQuery(
      priorities: <TaskPriority>{TaskPriority.high, TaskPriority.low},
    );
    const TaskQuery b = TaskQuery(
      priorities: <TaskPriority>{TaskPriority.low, TaskPriority.high},
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  group('viewOf 把查询条件反推成视图', () {
    test('要已完成就是「已完成」', () {
      expect(
        TaskQueryNotifier.viewOf(const TaskQuery(showCompleted: true)),
        DefaultView.completed,
      );
    });

    test('只看今天就是「今天」', () {
      expect(
        TaskQueryNotifier.viewOf(const TaskQuery(dueTodayOnly: true)),
        DefaultView.today,
      );
    });

    test('今天再叠加清单筛选就不算纯「今天」', () {
      expect(
        TaskQueryNotifier.viewOf(
          const TaskQuery(dueTodayOnly: true, listId: 'l1'),
        ),
        DefaultView.all,
      );
    });

    test('什么都不限制就是「全部」', () {
      expect(TaskQueryNotifier.viewOf(const TaskQuery()), DefaultView.all);
    });
  });
}
