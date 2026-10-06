import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/data/repositories/settings_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/focus/focus_page.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FocusSessionRepository sessions;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    sessions = FocusSessionRepository(db);
  });

  /// [initial] 对应 `main()` 里读出来的那份启动快照。
  ///
  /// 这里必须能在测试里给出它，而不是永远走默认值：`preferencesProvider`
  /// 是 stream，在假时钟里首次发射要几百毫秒才排到，而页面上每 1 秒一次的
  /// ticker 有可能在那之前就判一次「倒计时走满」。真实设备上这个窗口小到
  /// 看不见，但测试里不覆盖就是拿 `const AppPreferences()` 当设置用，
  /// 会走到一条真机上不会走的分支上去。
  Widget buildPage({String? taskId, AppPreferences? initial}) {
    return ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        initialPreferencesProvider.overrideWithValue(
          initial ?? const AppPreferences(),
        ),
      ],
      child: MaterialApp(home: FocusPage(taskId: taskId)),
    );
  }

  /// 等界面稳定。
  ///
  /// **不能用 `pumpAndSettle`**：会话跑起来之后有一个每秒触发重绘的
  /// `Timer.periodic`，帧永远排不空，`pumpAndSettle` 会一路跑到超时。
  /// 这里手动推帧，默认推 400 毫秒 —— 够让对话框的退场动画和输入框错误
  /// 文案的淡出跑完（两者都还在树上），又不到 1 秒，踩不响那个定时器。
  Future<void> settle(
    WidgetTester tester, {
    Duration total = const Duration(milliseconds: 400),
  }) async {
    for (int i = 0; i < (total.inMilliseconds / 16).ceil(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 读库。drift 的 future 要在真实的事件循环里落地，所以走 `runAsync`。
  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() action) async {
    return (await tester.runAsync(action)) as T;
  }

  /// 关库。**必须在用例体里、而且必须放在最后一步。**
  ///
  /// 原因见 `test/widget_test.dart` 里那段长注释：widget 用例跑在 fake async
  /// 区里，用例体返回后框架会先拆掉整棵树再断言「不许有未完成的定时器」，
  /// 而 drift 取消订阅时排的清理定时器永远不会跑。先关库就不排那个定时器了。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 「开始XX」那个按钮的启用状态。
  ///
  /// 不能用 `find.widgetWithText(FilledButton, ...)`：`FilledButton.icon`
  /// 造出来的是 `_FilledButtonWithIcon`，而 `find.byType` 比的是精确类型，
  /// 子类匹配不上。这里按「是 FilledButton」的谓词去找它的祖先。
  bool startEnabled(WidgetTester tester, String label) =>
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
            ),
          )
          .onPressed !=
      null;

  String minutesText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// 「记一笔」弹层里那个备注框。
  ///
  /// 不能写 `find.byType(TextField)`：会话一结束，页面就切回设置态（那里也有
  /// 一个 TextField），而弹层还开着 —— 两个都在树上，`enterText` 会直接抛
  /// 「Bad state: Too many elements」。这里按标签定位。
  Finder noteField() =>
      find.ancestor(of: find.text('记一笔（可选）'), matching: find.byType(TextField));

  Future<List<TodoFocusSession>> allSessions(WidgetTester tester) =>
      readDb(tester, () => sessions.watchAll().first);

  group('未开始：设置', () {
    testWidgets('默认是专注 + 倒计时 + 25 分钟', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      expect(find.text('开始专注'), findsOneWidget);
      expect(minutesText(tester), '25');
      expect(find.text('可以填 5–180'), findsOneWidget);
      expect(startEnabled(tester, '开始专注'), isTrue);

      await closeDatabase(tester);
    });

    testWidgets('时长越界：按钮禁用，并且说明为什么', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '3');
      await settle(tester);

      expect(find.text('太短了，最少 5 分钟。'), findsOneWidget);
      expect(startEnabled(tester, '开始专注'), isFalse);

      await closeDatabase(tester);
    });

    testWidgets('改回合法值之后又能开始了', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '3');
      await settle(tester);
      await tester.enterText(find.byType(TextField), '45');
      await settle(tester);

      expect(find.text('太短了，最少 5 分钟。'), findsNothing);
      expect(startEnabled(tester, '开始专注'), isTrue);

      await closeDatabase(tester);
    });

    testWidgets('切到短休息：时长回到休息自己的默认值，边界也跟着换', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      await tester.tap(find.text('短休息'));
      await settle(tester);

      // 从 25 分钟专注切过来还留着 25，是件很怪的事。
      expect(minutesText(tester), '5');
      expect(find.text('可以填 1–60'), findsOneWidget);
      expect(find.text('开始短休息'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('切到正计时：不再要求填时长，改为说明它不限时', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      await tester.tap(find.text('正计时'));
      await settle(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('正计时不限时，想停的时候自己点结束。它不会被算成「没完成」。'), findsOneWidget);
      // 按钮上的字跟的是会话类型，不是计时模式：换成正计时它还是「开始专注」。
      expect(startEnabled(tester, '开始专注'), isTrue);

      await closeDatabase(tester);
    });
  });

  group('进行中', () {
    testWidgets('开始之后落到库里，并且界面上是那一组控制', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);

      await tester.tap(find.text('开始专注'));
      await settle(tester);

      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('放弃'), findsOneWidget);
      expect(find.text('结束'), findsOneWidget);
      expect(find.text('还剩'), findsOneWidget);
      expect(find.text('自由专注'), findsOneWidget);

      final TodoFocusSession? running = await readDb(tester, sessions.running);
      expect(running, isNotNull);
      expect(running!.kind, FocusSessionKind.focus);
      expect(running.timerMode, FocusTimerMode.countDown);
      expect(running.plannedSeconds, 1500);
      expect(running.isRunning, isTrue);

      await closeDatabase(tester);
    });

    testWidgets('带上 taskId 进来时，一开就挂在那条任务上', (WidgetTester tester) async {
      final String? id = await readDb(
        tester,
        () => TaskRepository(db).create(title: '写周报'),
      );

      await tester.pumpWidget(buildPage(taskId: id));
      await settle(tester);
      await tester.tap(find.text('开始专注'));
      await settle(tester);

      expect(find.text('写周报'), findsOneWidget);
      final TodoFocusSession? running = await readDb(tester, sessions.running);
      expect(running!.taskId, id);

      await closeDatabase(tester);
    });

    testWidgets('暂停之后按钮变成继续，恢复之后变回来', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);
      await tester.tap(find.text('开始专注'));
      await settle(tester);

      await tester.tap(find.text('暂停'));
      await settle(tester);
      expect(find.text('继续'), findsOneWidget);
      expect(find.text('已暂停'), findsOneWidget);
      expect((await readDb(tester, sessions.running))!.isPaused, isTrue);

      await tester.tap(find.text('继续'));
      await settle(tester);
      expect(find.text('暂停'), findsOneWidget);
      expect((await readDb(tester, sessions.running))!.isPaused, isFalse);

      await closeDatabase(tester);
    });

    testWidgets('放弃要先确认；选「继续计时」就当作没点过', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);
      await tester.tap(find.text('开始专注'));
      await settle(tester);

      await tester.tap(find.widgetWithText(TextButton, '放弃'));
      await settle(tester);
      expect(find.text('放弃这一段？'), findsOneWidget);

      await tester.tap(find.text('继续计时'));
      await settle(tester);

      expect(find.text('放弃这一段？'), findsNothing);
      expect(find.text('暂停'), findsOneWidget);
      expect(await readDb(tester, sessions.running), isNotNull);

      await closeDatabase(tester);
    });

    testWidgets('确认放弃之后回到设置态，库里不留这一条', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);
      await tester.tap(find.text('开始专注'));
      await settle(tester);

      await tester.tap(find.widgetWithText(TextButton, '放弃'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '放弃'));
      await settle(tester);

      expect(find.text('开始专注'), findsOneWidget);
      expect(await readDb(tester, sessions.running), isNull);
      expect(await readDb(tester, () => sessions.watchAll().first), isEmpty);

      await closeDatabase(tester);
    });
  });

  group('结束后记一笔', () {
    testWidgets('结束时弹记一笔，保存会写进备注与归属', (WidgetTester tester) async {
      final String? id = await readDb(
        tester,
        () => TaskRepository(db).create(title: '写周报'),
      );

      await tester.pumpWidget(buildPage());
      await settle(tester);
      await tester.tap(find.text('开始专注'));
      await settle(tester);
      await tester.tap(find.text('结束'));
      await settle(tester);

      // 没走满的倒计时不该说「走满了」。
      expect(find.text('这一段记下了'), findsOneWidget);
      expect(find.text('接着下一段'), findsOneWidget);

      await tester.enterText(noteField(), '写了三分之一');
      await settle(tester);
      await tester.tap(find.text('保存'));
      await settle(tester);

      expect(find.text('这一段记下了'), findsNothing);
      expect(find.text('开始专注'), findsOneWidget);

      final TodoFocusSession stored = (await allSessions(tester)).single;
      expect(stored.isRunning, isFalse);
      expect(stored.note, '写了三分之一');
      expect(stored.completed, isFalse);

      // 归属没在弹层里选，就还是原来那条。
      expect(stored.taskId, isNull);
      expect(id, isNotNull);

      await closeDatabase(tester);
    });

    testWidgets('休息结束不给「接着下一段」', (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await settle(tester);
      await tester.tap(find.text('短休息'));
      await settle(tester);
      await tester.tap(find.text('开始短休息'));
      await settle(tester);

      await tester.tap(find.text('结束'));
      await settle(tester);

      expect(find.text('这一段记下了'), findsOneWidget);
      expect(find.text('接着下一段'), findsNothing);

      await tester.tap(find.text('保存'));
      await settle(tester);

      final TodoFocusSession stored = (await allSessions(tester)).single;
      expect(stored.kind, FocusSessionKind.shortBreak);
      expect(stored.isRunning, isFalse);

      await closeDatabase(tester);
    });
  });

  group('倒计时走满', () {
    /// 造一条「[ago] 分钟之前开始、计划 25 分钟」的会话。
    ///
    /// 这是「App 被划掉之后过了很久才重开」的数据形态：内存里什么都没有，
    /// 库里那条按时间戳算已经走满了。真等一下午是测不出来的。
    Future<void> seedExpired(WidgetTester tester, {int ago = 26}) async {
      await tester.runAsync(
        () => sessions.start(
          at: DateTime.now().subtract(Duration(minutes: ago)),
          logicalDate: dayOnlyMillis(DateTime.now()),
        ),
      );
    }

    /// 等到那个每秒一次的 ticker 真的走了一次。
    Future<void> waitForTick(WidgetTester tester) async {
      await settle(tester);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await settle(tester);
    }

    testWidgets('回到前台时自动收尾，并说清这是走满而不是被记下的', (WidgetTester tester) async {
      await seedExpired(tester);

      await tester.pumpWidget(buildPage());
      await waitForTick(tester);

      expect(find.text('这一段走满了'), findsOneWidget);
      expect(find.text('这一段记下了'), findsNothing);

      final TodoFocusSession stored = (await allSessions(tester)).single;
      expect(stored.isRunning, isFalse);
      expect(stored.completed, isTrue);
      expect(stored.actualSeconds, greaterThanOrEqualTo(25 * 60));

      await tester.tap(find.text('保存'));
      await settle(tester);
      await closeDatabase(tester);
    });

    testWidgets('开了自动接续就接着开一段休息，而不是弹「记一笔」', (WidgetTester tester) async {
      await tester.runAsync(
        () => SettingsRepository(db).update(autoStartNext: true),
      );
      await seedExpired(tester);

      await tester.pumpWidget(
        buildPage(initial: const AppPreferences(autoStartNext: true)),
      );
      await waitForTick(tester);

      expect(find.text('这一段走满了'), findsNothing);
      expect(find.text('暂停'), findsOneWidget);

      final List<TodoFocusSession> all = await allSessions(tester);
      expect(all, hasLength(2));
      final TodoFocusSession next = all.firstWhere(
        (TodoFocusSession s) => s.isRunning,
      );
      // 今天这是第 1 轮专注，按默认「每 4 轮长休息」应该接短休息。
      expect(next.kind, FocusSessionKind.shortBreak);
      expect(next.plannedSeconds, 5 * 60);
      expect(find.text('短休息'), findsOneWidget);

      await closeDatabase(tester);
    });
  });
}
