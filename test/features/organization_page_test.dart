import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/constants/app_constants.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/theme/entity_palette.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/organization/lists_page.dart';
import 'package:now_todo/features/organization/tags_page.dart';

import '../helpers/test_database.dart';

// 两个小包装，用来在真异步区里碰数据库。
//
// 直接写 `await tester.runAsync(...)!` 是不行的：那个 `!` 作用在 Future 对象
// 上，去掉的是 Future 自己的可空性，`await` 出来仍然是 `T?`。分成「不取结果」
// 和「取结果」两个名字，是因为 `void` 塞不进带 `extends Object` 约束的那个。
Future<void> inDatabase(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  await tester.runAsync(body);
}

Future<T> readDatabase<T extends Object>(
  WidgetTester tester,
  Future<T> Function() body,
) async => (await tester.runAsync(body))!;

void main() {
  late AppDatabase db;
  late ListRepository lists;
  late TagRepository tags;
  late TaskRepository tasks;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    lists = ListRepository(db);
    tags = TagRepository(db);
    tasks = TaskRepository(db);
  });

  /// 起一个容器，把这一页单独挂上去。
  ///
  /// 返回容器是为了直接读 provider：这一页有两处行为只在状态里看得见
  /// （点一条清单 / 一个标签会带上筛选条件），比去界面里找文字稳。
  Future<ProviderContainer> pumpPage(WidgetTester tester, Widget page) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // 页面里用了 `context.canPop()`（go_router 的扩展），所以上面必须挂着
    // 一个真的 GoRouter：只给 MaterialApp，点列表项时会抛
    // 「No GoRouter found in context」。
    final GoRouter router = GoRouter(
      initialLocation: '/page',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/page', builder: (_, _) => page),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return container;
  }

  /// 关库，**必须在用例体里、而且放在最后一步**（理由见 widget_test.dart）。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 改名 / 换颜色弹窗里第 [index] 个色块。0 是「不选颜色」，1..8 是调色板。
  Finder swatch(int index) => find
      .descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(InkResponse),
      )
      .at(index);

  group('清单页', () {
    testWidgets('列出所有清单，各带自己的待办数', (WidgetTester tester) async {
      final String work = await readDatabase(tester, () => lists.create('工作'));
      await inDatabase(tester, () async {
        await tasks.create(title: 'A', listId: work);
        await tasks.create(title: 'B', listId: work);
        // 不带清单的任务是「未分类」，不算进收件箱的待办数——这是当前
        // schema 的语义（收件箱也是一条普通清单）。
        await tasks.create(title: 'C', listId: AppConstants.inboxListId);
      });

      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      expect(find.text('收件箱'), findsOneWidget);
      expect(find.text('工作'), findsOneWidget);
      expect(find.text('2 条待办'), findsOneWidget);
      expect(find.text('1 条待办'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('新建清单会落库，并带上选的颜色', (WidgetTester tester) async {
      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建清单'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '工作');
      // 第 4 个色块 = EntityPalette.colors[3]，0 号是「不选颜色」。
      await tester.tap(swatch(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final List<TodoList> all = await readDatabase(
        tester,
        () => lists.watch().first,
      );
      final TodoList created = all.firstWhere((TodoList l) => l.name == '工作');
      expect(created.color, EntityPalette.colors[3].toARGB32());
      expect(find.text('工作'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('名字为空时保存按钮按不动', (WidgetTester tester) async {
      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建清单'));
      await tester.pumpAndSettle();

      // 只有空白也算空。
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final FilledButton save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '保存'),
      );
      expect(save.onPressed, isNull);
      expect(find.text('清单名不能是空的'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('重命名和换颜色都写进库里', (WidgetTester tester) async {
      final String id = await readDatabase(tester, () => lists.create('工作'));

      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      // 第一行是收件箱，第二行才是刚建的这条。
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名 / 换颜色'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '项目');
      await tester.tap(swatch(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final List<TodoList> all = await readDatabase(
        tester,
        () => lists.watch().first,
      );
      final TodoList updated = all.firstWhere((TodoList l) => l.id == id);
      expect(updated.name, '项目');
      expect(updated.color, EntityPalette.colors.first.toARGB32());
      expect(find.text('项目'), findsOneWidget);
      expect(find.text('工作'), findsNothing);

      await closeDatabase(tester);
    });

    testWidgets('删除前说清里面的任务会回到未分类，删完任务还在', (WidgetTester tester) async {
      final String id = await readDatabase(tester, () => lists.create('临时'));
      final String taskId = await readDatabase(
        tester,
        () => tasks.create(title: '搬家', listId: id),
      );

      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 这句话是那个「删除」按钮能不能按的前提，不能省。
      expect(find.text('里面的 1 条未完成任务不会被删掉，它们会回到未分类。'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(find.text('临时'), findsNothing);
      final TodoTask? task = await tester.runAsync<TodoTask?>(
        () => tasks.findById(taskId),
      );
      expect(task, isNotNull);
      expect(task!.listId, isNull);

      await closeDatabase(tester);
    });

    testWidgets('内置收件箱的删除项是灰的，并写明原因', (WidgetTester tester) async {
      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      // 只有一条清单，就是收件箱。
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('内置清单不能删除'), findsOneWidget);
      final PopupMenuItem<String> item = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text('内置清单不能删除'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      // 留一个按下去能点的「删除」对用户是种欺骗。
      expect(item.enabled, isFalse);

      await closeDatabase(tester);
    });

    testWidgets('点一条清单会把它设成首页的筛选条件', (WidgetTester tester) async {
      final String id = await readDatabase(tester, () => lists.create('工作'));

      final ProviderContainer container = await pumpPage(
        tester,
        const ListsPage(),
      );
      await tester.pumpAndSettle();
      expect(container.read(taskQueryProvider).listId, isNull);

      await tester.tap(find.text('工作'));
      await tester.pumpAndSettle();

      expect(container.read(taskQueryProvider).listId, id);

      await closeDatabase(tester);
    });

    testWidgets('清单为空时给的是初始化没跑完的线索，不是编出来的空态', (WidgetTester tester) async {
      // 内置收件箱由 `ensureInitialized()` 保证存在，所以正常不可能为空。
      // 手工造出这个局面，验证这一屏说的是实话。
      await inDatabase(tester, () => db.delete(db.taskLists).go());

      await pumpPage(tester, const ListsPage());
      await tester.pumpAndSettle();

      expect(find.text('清单是空的'), findsOneWidget);
      expect(find.textContaining('数据库初始化没跑完'), findsOneWidget);

      await closeDatabase(tester);
    });
  });

  group('标签页', () {
    testWidgets('没有标签时说明标签是从哪来的', (WidgetTester tester) async {
      await pumpPage(tester, const TagsPage());
      await tester.pumpAndSettle();

      expect(find.text('还没有标签'), findsOneWidget);
      expect(find.textContaining('在任务里直接敲一个名字就会建出来'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('新建标签会落库', (WidgetTester tester) async {
      await pumpPage(tester, const TagsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建标签'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '紧急');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final List<TodoTag> all = await readDatabase(
        tester,
        () => tags.watch().first,
      );
      expect(all.map((TodoTag tag) => tag.name), <String>['紧急']);
      expect(find.text('还没有任务用过'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('改名和换颜色都写进库里', (WidgetTester tester) async {
      final String id = await readDatabase(tester, () => tags.create('work'));

      await pumpPage(tester, const TagsPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('改名 / 换颜色'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'job');
      await tester.tap(swatch(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final List<TodoTag> all = await readDatabase(
        tester,
        () => tags.watch().first,
      );
      expect(all.single.id, id);
      expect(all.single.name, 'job');
      expect(all.single.color, EntityPalette.colors[1].toARGB32());
      expect(find.text('job'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('删标签不删任务，弹窗里把这件事说清楚', (WidgetTester tester) async {
      final String taskId = await readDatabase(
        tester,
        () => tasks.create(title: '写周报'),
      );
      await inDatabase(
        tester,
        () => tasks.setTaskTags(taskId, <String>['work']),
      );

      await pumpPage(tester, const TagsPage());
      await tester.pumpAndSettle();
      expect(find.text('1 条任务'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('挂在 1 条任务上的这个标记会被去掉，任务本身不会被删掉。'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(await readDatabase(tester, () => tags.watch().first), isEmpty);
      final TodoTask? task = await tester.runAsync<TodoTask?>(
        () => tasks.findById(taskId),
      );
      expect(task!.title, '写周报');
      expect(task.tagNames, isEmpty);

      await closeDatabase(tester);
    });

    testWidgets('点一个标签会按它筛选', (WidgetTester tester) async {
      await inDatabase(tester, () => tags.create('紧急'));

      final ProviderContainer container = await pumpPage(
        tester,
        const TagsPage(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('紧急'));
      await tester.pumpAndSettle();

      expect(container.read(taskQueryProvider).tagName, '紧急');

      await closeDatabase(tester);
    });
  });
}
