import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/app/app.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

/// 首页的筛选入口。
///
/// 这里挂的是**整个应用**而不是单独一页：筛选面板、首页、清单页之间靠
/// go_router 和共享的 `taskQueryProvider` 串起来，单独挂 HomePage 会把
/// 「点一条清单回首页」这类行为测成假的。
void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late ListRepository lists;
  late TagRepository tags;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    tasks = TaskRepository(db);
    lists = ListRepository(db);
    tags = TagRepository(db);
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

  /// 在真异步区里碰数据库。
  ///
  /// 直接写 `await tester.runAsync(...)!` 不行：那个 `!` 作用在 Future 对象上，
  /// 去掉的是 Future 自己的可空性，取出来仍然是 `T?`。分成「取结果」和
  /// 「不取结果」两个名字，是因为 `void` 塞不进带 `extends Object` 约束的那个。
  Future<T> inDatabase<T extends Object>(
    WidgetTester tester,
    Future<T> Function() body,
  ) async => (await tester.runAsync(body))!;

  Future<void> runInDatabase(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    await tester.runAsync(body);
  }

  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 打开筛选面板。
  Future<void> openFilterSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('筛选'), findsOneWidget);
  }

  /// 点面板外面把它收掉——这就是用户的手势，比 `Navigator.pop` 诚实。
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('筛选'), findsNothing);
  }

  testWidgets('选一条清单，列表只剩它的任务，条件条上写着它', (WidgetTester tester) async {
    final String work = await inDatabase(tester, () => lists.create('工作'));
    await runInDatabase(tester, () async {
      await tasks.create(title: '交周报', listId: work);
      await tasks.create(title: '买菜');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsOneWidget);

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '工作'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('买菜'), findsNothing);
    // 条件得写在脸上：不然「列表怎么空了」只能靠猜。
    expect(find.text('清单：工作'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('优先级可以多选，条件条按枚举顺序列出来', (WidgetTester tester) async {
    await runInDatabase(tester, () async {
      await tasks.create(title: '低优先', priority: TaskPriority.low);
      await tasks.create(title: '中优先', priority: TaskPriority.medium);
      await tasks.create(title: '高优先', priority: TaskPriority.high);
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(FilterChip, '高'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '低'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(find.text('高优先'), findsOneWidget);
    expect(find.text('低优先'), findsOneWidget);
    expect(find.text('中优先'), findsNothing);
    expect(find.text('优先级：低、高'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('一键清空把所有条件一起清掉，条件条本身也消失', (WidgetTester tester) async {
    final String work = await inDatabase(tester, () => lists.create('工作'));
    await runInDatabase(tester, () async {
      await tasks.create(title: '交周报', listId: work);
      await tasks.create(title: '买菜');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '工作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '高'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(find.text('买菜'), findsNothing);
    expect(find.text('清单：工作'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('买菜'), findsOneWidget);
    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('清单：工作'), findsNothing);
    // 条件条只在有条件时占位置。
    expect(find.byType(InputChip), findsNothing);

    await closeDatabase(tester);
  });

  testWidgets('筛到一条不剩时说的是「没有符合条件的任务」，而不是「这里很干净」', (WidgetTester tester) async {
    await inDatabase(tester, () => lists.create('工作'));
    await inDatabase(tester, () => tasks.create(title: '买菜'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '工作'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(find.text('没有符合条件的任务'), findsOneWidget);
    expect(find.text('这里很干净'), findsNothing);

    // 空态里那个按钮走的是同一条 clearFilters。
    await tester.tap(find.text('清空筛选'));
    await tester.pumpAndSettle();

    expect(find.text('买菜'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('筛选面板里的标签选项来自库里的标签', (WidgetTester tester) async {
    await inDatabase(tester, () => tags.create('紧急'));
    final String id = await inDatabase(
      tester,
      () => tasks.create(title: '交周报'),
    );
    await runInDatabase(tester, () => tasks.setTaskTags(id, <String>['紧急']));
    await inDatabase(tester, () => tasks.create(title: '买菜'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '紧急'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('买菜'), findsNothing);
    expect(find.text('标签：紧急'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('更多菜单里有清单和标签的入口，点进去是那一页', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);

    await tester.tap(find.text('清单'));
    await tester.pumpAndSettle();
    expect(find.text('新建清单'), findsOneWidget);

    await closeDatabase(tester);
  });
}
