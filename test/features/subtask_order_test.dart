import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/data/database/app_database.dart' as database;
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/task_editor/task_editor_page.dart';

import '../helpers/test_database.dart';

/// 子任务排序。
///
/// 拖拽手势本身是 `ReorderableListView` 的事，这里要守的是**我们自己的两行**：
/// 把 `onReorder` 的「插到第几个之前」翻译成列表下标，以及把它写回库里。
/// 所以直接调回调，不去模拟长按拖拽——那样测的是 Flutter 的实现。
void main() {
  late database.AppDatabase db;
  late TaskRepository tasks;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    tasks = TaskRepository(db);
  });

  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action)) as T;

  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  Future<void> pumpEditor(WidgetTester tester, String taskId) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/editor',
          builder: (_, _) => TaskEditorPage(taskId: taskId),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push('/editor'));
    await tester.pumpAndSettle();
  }

  Future<List<String>> titles(String taskId) async {
    final List<TodoSubtask> items = await tasks.watchSubtasks(taskId).first;
    return <String>[for (final TodoSubtask item in items) item.title];
  }

  /// 子任务在表单靠下的位置，800×600 的测试视口里默认还没被建出来。
  Future<void> scrollToSubtasks(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('添加子任务'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('把第一条拖到最后，库里跟着换顺序', (WidgetTester tester) async {
    final String id = await tasks.create(title: '搬家');
    await tasks.addSubtask(id, '打包');
    await tasks.addSubtask(id, '叫车');
    await tasks.addSubtask(id, '取钥匙');

    await pumpEditor(tester, id);
    await scrollToSubtasks(tester);
    expect(find.text('打包'), findsOneWidget);

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // 「把第 0 条拖到第 2 个位置之前」。
    list.onReorder(0, 2);
    await tester.pumpAndSettle();

    expect(await readDb(tester, () => titles(id)), <String>['叫车', '打包', '取钥匙']);

    await closeDatabase(tester);
  });

  testWidgets('往下拖时不会因为 off-by-one 停在原地', (WidgetTester tester) async {
    final String id = await tasks.create(title: '搬家');
    await tasks.addSubtask(id, '打包');
    await tasks.addSubtask(id, '叫车');

    await pumpEditor(tester, id);
    await scrollToSubtasks(tester);

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // 拖到列表末尾。`to` 已经算上被拖走的那一项，所以这里必须是「插到 1」，
    // 不是「插到 2」——差一位的表现是拖到最后一条却什么都没动。
    list.onReorder(0, 2);
    await tester.pumpAndSettle();

    expect(await readDb(tester, () => titles(id)), <String>['叫车', '打包']);

    await closeDatabase(tester);
  });

  testWidgets('拖拽用的是稳定 key，勾选状态不会串行', (WidgetTester tester) async {
    final String id = await tasks.create(title: '搬家');
    final String packed = await tasks.addSubtask(id, '打包');
    await tasks.addSubtask(id, '叫车');
    await tasks.setSubtaskDone(packed, true);

    await pumpEditor(tester, id);
    await scrollToSubtasks(tester);

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(0, 2);
    await tester.pumpAndSettle();

    // 勾选状态跟着「打包」走，不会因为换了位置就跑到「叫车」头上。
    final List<TodoSubtask> items = await readDb(
      tester,
      () => tasks.watchSubtasks(id).first,
    );
    expect(
      <String>[
        for (final TodoSubtask item in items)
          if (item.isDone) item.title,
      ],
      <String>['打包'],
    );

    await closeDatabase(tester);
  });
}
