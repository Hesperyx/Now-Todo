// 徽章页的用例。
//
// 这里守的是**页面承诺**与**架构承诺**：没有记录时给空态、解锁枚数与
// 「还差多少」对得上、新记录写进去之后重进页面就是新的数字，以及
// 仓库里确实没有一张「解锁记录」表——那正是 F5 不做持久化的意思。
//
// 徽章判定本身的口径在 `test/core/focus/achievements_test.dart` 里咬。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/app.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/app/router.dart';
import 'package:now_todo/core/notifications/notification_service.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/features/focus/achievements_page.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FocusSessionRepository sessions;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    sessions = FocusSessionRepository(db);
  });

  /// 读库：drift 的 future 要在真实的事件循环里落地。
  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() action) async {
    return (await tester.runAsync(action)) as T;
  }

  /// 关库。**必须放在用例体的最后一步**，理由见 `test/widget_test.dart` 的长注释。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 种一段已经结束的专注（收尾时刻写死，数字不随执行时刻漂）。
  Future<void> seed(
    WidgetTester tester, {
    required DateTime startedAt,
    required Duration duration,
  }) async {
    await readDb(tester, () async {
      final String id = await sessions.start(
        at: startedAt,
        logicalDate: dayOnlyMillis(startedAt),
        plan: duration,
      );
      await sessions.finish(id, at: startedAt.add(duration));
    });
  }

  DateTime todayAt(int hour, [int minute = 0]) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  late GoRouter router;

  /// 只挂徽章页 + 一个首页占位、一个专注占位：跳走的那两个入口要看得见。
  Future<void> pumpPage(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: AppRoutes.achievements,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('首页占位'))),
        ),
        GoRoute(
          path: '/focus',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('专注占位'))),
        ),
        GoRoute(
          path: AppRoutes.achievements,
          builder: (BuildContext context, GoRouterState state) =>
              const AchievementsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  /// 滚到某个东西看得见为止：徽章一共 14 条，最后几条在视口外。
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// 一枚徽章那一行（标题所在的那张卡片）。
  ///
  /// 断言要限定在行里：「还差 90 分钟」这种文案在别的行上也会命中，
  /// 不限定就分不清是谁写的。
  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card));

  testWidgets('一条记录都没有时给空态，按钮能跳去专注页', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.text('还没有专注记录'), findsOneWidget);
    expect(find.text('去专注'), findsOneWidget);
    // 空态下不列徽章，免得第一次进来就是 14 行「还差」。
    expect(find.text('第一步'), findsNothing);

    await tester.tap(find.text('去专注'));
    await tester.pumpAndSettle();
    expect(find.text('专注占位'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('第一段 25 分钟解锁一枚，没到的那枚写着还差多少', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);

    expect(find.text('已解锁 1 / 14'), findsOneWidget);
    expect(find.text('第一步'), findsOneWidget);
    // 屏上先出现的那几枚：解锁的那枚没有进度行，没解锁的写着还差多少。
    // （14 行里视口外的不会建出来，所以这里只咬看得见的部分。）
    expect(find.text('满一小时'), findsOneWidget);
    expect(find.text('还差 1 小时'), findsOneWidget);

    // 最后一条徽章滚得到，而且写着还差多少天。
    await scrollTo(tester, find.text('连续一个月'));
    expect(find.text('连续一个月'), findsOneWidget);
    // 「连续一个月」看的是最长连续：只有今天这一段，所以最长就是 1 天，还差 29 天。
    expect(
      find.descendant(
        of: row('连续一个月'),
        matching: find.textContaining('还差 29 天'),
      ),
      findsOneWidget,
    );

    await closeDatabase(tester);
  });

  testWidgets('一段 90 分钟同时拿下「第一步」「满一小时」「长跑」', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(9),
      duration: const Duration(minutes: 90),
    );
    await pumpPage(tester);

    expect(find.text('已解锁 3 / 14'), findsOneWidget);
    // 「满一小时」拿到了，所以它那一行不再写「还差 1 小时」。
    expect(find.text('满一小时'), findsOneWidget);
    expect(find.text('还差 1 小时'), findsNothing);
    // 长跑那一条在屏外，滚过去看它确实解锁了（解锁的行没有「还差」行）。
    await scrollTo(tester, find.text('长跑'));
    expect(
      find.descendant(of: row('长跑'), matching: find.textContaining('还差')),
      findsNothing,
    );
    // 而「深度一天」要的是单日累计 180 分钟，所以它还在还差 90 分钟。
    expect(
      find.descendant(
        of: row('深度一天'),
        matching: find.textContaining('还差 90 分钟'),
      ),
      findsOneWidget,
    );

    await closeDatabase(tester);
  });

  testWidgets('新记录写进去之后，重新进徽章页就是新的数字', (WidgetTester tester) async {
    await pumpPage(tester);
    expect(find.text('还没有专注记录'), findsOneWidget);

    // 用户去专注了一段，再回来。
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await go(tester, '/');
    await go(tester, AppRoutes.achievements);

    expect(find.text('已解锁 1 / 14'), findsOneWidget);
    expect(find.text('还没有专注记录'), findsNothing);

    await closeDatabase(tester);
  });

  testWidgets('走真实路由表也能到徽章页', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          const NoopNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NowTodoApp(),
      ),
    );
    // 首页每秒重绘，`pumpAndSettle` 排不空帧；手动推 30 帧 = 480ms。
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    container.read(appRouterProvider).go(AppRoutes.achievements);
    await tester.pumpAndSettle();

    expect(find.byType(AchievementsPage), findsOneWidget);
    expect(find.text('还没有专注记录'), findsOneWidget);

    await closeDatabase(tester);
  });

  test('仓库里就是那九张表，没有「解锁记录」表', () async {
    // 验收第 3 条是条机械断言：徽章状态是派生值，落表就会多出一个
    // 「改了判定规则之后已解锁的还算不算」的问题。
    // 问 sqlite 自己有哪些表，而不是读 drift 的元数据——前者才是真的。
    final List<String> names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'",
                )
                .get())
            .map((row) => row.read<String>('name'))
            .where((String name) => !name.startsWith('sqlite_'))
            .toList()
          ..sort();
    expect(
      names.where((String name) => name.toLowerCase().contains('achievement')),
      isEmpty,
      reason: '徽章不该有自己的表',
    );
    // 数一遍也有用：将来加表必须是有意的（加表要同步升 schemaVersion）。
    expect(names, <String>[
      'app_settings',
      'focus_sessions',
      'recurrence_rules',
      'reminders',
      'subtasks',
      'tags',
      'task_lists',
      'task_tags',
      'tasks',
    ]);
  });
}
