import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/app/app.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/models/task_query.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
  });

  /// 默认视图固定成「全部」：默认的「今天」只看今天到期的任务，
  /// 会让「刚建好、没填日期」的任务从列表里消失——那看着像 bug，其实不是。
  Widget buildApp() {
    return ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        initialPreferencesProvider.overrideWithValue(
          AppPreferences(defaultView: DefaultView.all),
        ),
      ],
      child: const NowTodoApp(),
    );
  }

  /// 关库。**必须在用例体里调用，而且必须放在最后一步。**
  ///
  /// 原因（都在 drift 源码里，不是猜的）：
  /// drift 在取消订阅时会用 `Timer.run` 排一个「延迟一会儿再清理缓存」的任务
  /// （`drift-2.31.0/lib/src/runtime/executor/stream_queries.dart:154`）。
  /// 而 widget 用例跑在 fake async 区里：`flutter_test` 会在用例体返回后
  /// 先 `runApp(Container(...))` 拆掉整棵树（`flutter_test/lib/src/binding.dart:1066`，
  /// 那一步会 dispose `ProviderScope`，进而取消 drift 订阅、排出定时器），
  /// 紧接着断言「不许有未完成的定时器」（同文件 `:1617`）——定时器永远不会跑，
  /// 于是每个用例都以 `A Timer is still pending even after the widget tree was
  /// disposed.` 收尾。
  ///
  /// 先关库就能绕开：`StreamQueryStore.close()` 会置上 `_isShuttingDown`
  /// （同文件 `:178`），之后取消订阅直接返回（`:133`），压根不排定时器。
  /// drift 源码 `:148` 那句 "please call and await Database.close() in your
  /// Flutter widget tests!" 说的就是这件事。
  ///
  /// 反过来，**不能把它挪到 `tearDown` 里**：那时定时器已经排下，而
  /// `close()` 会卡在 `while (_pendingTimers.isNotEmpty) { await _pendingTimers
  /// .first.future; }`（同文件 `:189`）上永不返回——整个测试文件直接挂死。
  /// 这个坑是实测踩出来的：`flutter_tester` 跑满 14 分钟只花了 0.2 秒 CPU。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  testWidgets('空库时给出空态文案，不是一片空白', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('这里很干净'), findsOneWidget);
    expect(find.text('新建'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('库里已有的任务会显示出来', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await TaskRepository(db).create(title: '写周报');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('这里很干净'), findsNothing);

    await closeDatabase(tester);
  });

  testWidgets('从首页走到新建页，保存后回到首页并看到新任务', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '写周报');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 回到首页，列表里看得到它。
    expect(find.text('写周报'), findsOneWidget);

    // 而且真的落库了，不是只活在界面里。
    final List<TodoTask>? stored = await tester.runAsync(() {
      return TaskRepository(db).watch(const TaskQuery()).first;
    });
    expect(stored!.map((TodoTask task) => task.title), <String>['写周报']);

    await closeDatabase(tester);
  });

  testWidgets('勾上复选框会把任务标成已完成', (WidgetTester tester) async {
    final String? id = await tester.runAsync(() {
      return TaskRepository(db).create(title: '写周报');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final TodoTask? task = await tester.runAsync<TodoTask?>(() {
      return TaskRepository(db).findById(id!);
    });
    expect(task!.isCompleted, isTrue);

    await closeDatabase(tester);
  });

  testWidgets('搜索框会把不匹配的任务过滤掉', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final TaskRepository repo = TaskRepository(db);
      await repo.create(title: '写周报');
      await repo.create(title: '买菜');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '周报');
    await tester.pumpAndSettle();

    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买菜'), findsNothing);

    await closeDatabase(tester);
  });
}
