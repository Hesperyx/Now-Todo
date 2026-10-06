// 统计页的用例。
//
// 这里守的是**页面的承诺**：没有记录时给空态而不是一张全 0 的图、
// 「来过但没计时」和「什么都没干」在图上不是一回事、切档位真的换了口径。
// 数字本身的口径在 `test/core/focus/focus_stats_test.dart` 里咬。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/features/focus/stats_page.dart';
import 'package:now_todo/features/focus/widgets/heatmap.dart';

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

  /// 种一段已经结束的专注。
  ///
  /// 时长写死成「开始 + 时长」的收尾时刻，而不是让 `finish` 去读「现在」——
  /// 否则用例的数字会随执行时刻漂。
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

  DateTime daysAgoAt(int days, int hour) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day - days, hour);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/stats',
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
          path: '/stats',
          builder: (BuildContext context, GoRouterState state) =>
              const StatsPage(),
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

  /// 滚到某个东西看得见为止。
  ///
  /// 统计页是一整条 `ListView`，热力图在最后一张卡片里，800×600 的测试视口里
  /// 一开始根本没被建出来。
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('一条记录都没有时给空态，而不是一张全 0 的图', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.text('还没有专注记录'), findsOneWidget);
    expect(find.text('去专注'), findsOneWidget);
    expect(find.byType(FocusMonthHeatmap), findsNothing);
    expect(find.byType(FocusYearHeatmap), findsNothing);

    // 空态里的按钮真的能跳走。
    await tester.tap(find.text('去专注'));
    await tester.pumpAndSettle();
    expect(find.text('专注占位'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('有记录但一秒没计时，仍然算有数据', (WidgetTester tester) async {
    await seed(tester, startedAt: todayAt(10), duration: Duration.zero);
    await pumpPage(tester);

    // 空态不该出现：这不是「还没开始用」，是「来过但没计时」。
    expect(find.text('还没有专注记录'), findsNothing);
    expect(find.text('最近一年'), findsOneWidget);
    expect(find.text('0 分钟'), findsOneWidget);
    expect(find.textContaining('共 1 次专注'), findsOneWidget);
    expect(find.textContaining('还没有足够的数据'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('今天这一段会出现在概览与高效时段里', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);

    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.textContaining('共 1 次专注，有记录 1 天'), findsOneWidget);
    expect(find.textContaining('最坐得住的是 10 点这一小时'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('连续天数：今天和昨天都有就是 2 天', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: daysAgoAt(1, 10),
      duration: const Duration(minutes: 25),
    );
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);

    // 「现在」与「最长」都是 2 天。
    expect(find.text('2 天'), findsNWidgets(2));
    expect(find.text('今天已经记上了。'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('今天还没开始专注时，连续天数不算断', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: daysAgoAt(1, 10),
      duration: const Duration(minutes: 25),
    );
    await seed(
      tester,
      startedAt: daysAgoAt(2, 10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);

    expect(find.text('2 天'), findsNWidgets(2));
    expect(find.text('今天还没开始，不算断。'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('热力图把「有记录没计时」和「没有记录」分开说', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await seed(tester, startedAt: todayAt(10), duration: Duration.zero);
    await pumpPage(tester);
    await scrollTo(tester, find.text('专注日历'));

    expect(find.text('来过没计时'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('但没计时')), findsOneWidget);
    // 同一个月里总还有没记录的日子，那些格子的说法是另一句。
    expect(find.bySemanticsLabel(RegExp('没有专注记录')), findsWidgets);

    handle.dispose();
    await closeDatabase(tester);
  });

  testWidgets('点一格热力格会说清那一天', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);
    await scrollTo(tester, find.text('专注日历'));

    final Finder cell = find.byKey(
      ValueKey<int>(dayOnlyMillis(DateTime.now())),
    );
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(formatLocalDate(DateTime.now())),
      findsOneWidget,
    );
    expect(find.textContaining('专注 25 分钟'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('日周月三档换的是口径说明与柱子', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);

    expect(find.text('最近 7 天'), findsOneWidget);
    await scrollTo(tester, find.text('时长分布'));
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(find.textContaining('最近 12 周'), findsOneWidget);
    await scrollTo(tester, find.text('时长分布'));
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('最近 12 个月'), findsOneWidget);

    await closeDatabase(tester);
  });

  testWidgets('年视图与月视图都画得出来，往回翻一个月也对得上', (WidgetTester tester) async {
    await seed(
      tester,
      startedAt: todayAt(10),
      duration: const Duration(minutes: 25),
    );
    await pumpPage(tester);
    await scrollTo(tester, find.text('专注日历'));

    final DateTime now = DateTime.now();
    expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget);

    await tester.tap(find.byTooltip('上一个月'));
    await tester.pumpAndSettle();
    final DateTime previous = DateTime(now.year, now.month - 1);
    expect(find.text('${previous.year} 年 ${previous.month} 月'), findsOneWidget);

    await tester.tap(find.text('年视图'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusYearHeatmap), findsOneWidget);
    expect(find.byType(FocusMonthHeatmap), findsNothing);

    await tester.tap(find.text('月视图'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusMonthHeatmap), findsOneWidget);

    await closeDatabase(tester);
  });
}
