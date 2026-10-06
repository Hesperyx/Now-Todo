import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart' as database;
import 'package:now_todo/data/repositories/recurrence_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/task_editor/task_editor_page.dart';

import '../helpers/test_database.dart';

/// `findForTask` 卡住不返回的仓储，用来复现「规则还在读」的那一瞬间。
///
/// 真实环境里这个窗口只有几毫秒，但它是**丢数据的窗口**：那一刻 `_recurrence`
/// 还是 null，点保存就等于把用户的规则删了。所以这个状态值得能稳定复现。
class _StuckRecurrence extends RecurrenceRepository {
  _StuckRecurrence(super.db);

  final Completer<RecurrenceRule?> gate = Completer<RecurrenceRule?>();

  @override
  Future<RecurrenceRule?> findForTask(String taskId) => gate.future;
}

void main() {
  late database.AppDatabase db;
  late ProviderContainer container;
  late TaskRepository tasks;
  late RecurrenceRepository recurrence;
  _StuckRecurrence? stuck;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    tasks = TaskRepository(db);
    recurrence = RecurrenceRepository(db);
    stuck = null;
    container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        // 只有用例里设了 stuck 才接管，别的时候用真的。
        recurrenceRepositoryProvider.overrideWith(
          (ref) => stuck ?? RecurrenceRepository(db),
        ),
      ],
    );
  });

  /// 读库。drift 的 future 要在真实的事件循环里落地，所以走 `runAsync`。
  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action)) as T;

  /// 关库。必须在用例体里、而且放在最后一步，理由见 `test/widget_test.dart`。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 编辑器要 `context.pop()`，所以不能只挂一个页面：给一个能弹回去的根路由。
  Future<void> pumpEditor(WidgetTester tester, {String? taskId}) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Center(child: Text('首页占位'))),
        ),
        GoRoute(
          path: '/editor',
          builder: (_, _) => TaskEditorPage(taskId: taskId),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push('/editor'));
    await tester.pumpAndSettle();
  }

  /// 弹窗里的按钮。页面底部那个「保存」也是一个 `FilledButton`，同名。
  Finder sheetButton(String label) => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(FilledButton, label),
  );

  Finder saveButton() => find.widgetWithText(FilledButton, '保存');

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton()).onPressed != null;

  Future<void> openSheet(WidgetTester tester, Finder openTarget) async {
    await tester.tap(openTarget);
    await tester.pumpAndSettle();
    expect(find.text('频率'), findsOneWidget, reason: '弹窗该开了');
  }

  Future<void> saveSheet(WidgetTester tester) async {
    await tester.tap(sheetButton('保存'));
    await tester.pumpAndSettle();
  }

  /// 造一条带规则的任务。锚点与截止日期可以不一样——「仅此一次」改过的实例
  /// 就是这个样子。
  Future<String> seedTask({
    required DateTime anchor,
    DateTime? due,
    RecurrenceFrequency frequency = RecurrenceFrequency.daily,
  }) async {
    final String ruleId = await recurrence.create(
      RecurrenceRule(startsOn: anchor, frequency: frequency),
    );
    return tasks.create(
      title: '交周报',
      dueDate: dayOnlyMillis(due ?? anchor),
      recurrenceRuleId: ruleId,
    );
  }

  /// 今天的本地零点（规则锚点与截止日期都用它，省得每次自己写一遍）。
  DateTime today() => fromUtcMillis(dayOnlyMillis(DateTime.now()));

  group('新建任务时设重复', () {
    testWidgets('「重复」区块一开始是「不重复」', (WidgetTester tester) async {
      await pumpEditor(tester);

      expect(find.text('重复'), findsOneWidget);
      expect(find.text('不重复'), findsOneWidget);
      expect(find.text('设置重复'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);

      await closeDatabase(tester);
    });

    testWidgets('没有截止日期时点「设置重复」，先补一个今天的日期', (WidgetTester tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('设置重复'));
      await tester.pumpAndSettle();

      expect(find.text('重复的任务要有截止日期，已经设成今天。'), findsOneWidget);
      expect(find.text('频率'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('选完之后区块说的是规则本身，还带上「下一次」', (WidgetTester tester) async {
      await pumpEditor(tester);

      await openSheet(tester, find.text('设置重复'));
      await tester.tap(find.widgetWithText(ChoiceChip, '每天'));
      await tester.pumpAndSettle();
      await saveSheet(tester);

      expect(find.text('不重复'), findsNothing);
      expect(find.text('每天'), findsOneWidget);
      expect(find.textContaining('下一次：'), findsOneWidget);
      expect(find.byTooltip('取消重复'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('保存之后规则真的挂到了任务上', (WidgetTester tester) async {
      await pumpEditor(tester);
      await tester.enterText(find.byType(TextField).first, '写周报');

      await openSheet(tester, find.text('设置重复'));
      await tester.tap(find.widgetWithText(ChoiceChip, '每周'));
      await tester.pumpAndSettle();
      await saveSheet(tester);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      final List<database.Task> rows = await readDb(
        tester,
        () => db.select(db.tasks).get(),
      );
      expect(rows, hasLength(1));
      expect(rows.single.title, '写周报');
      expect(rows.single.recurrenceRuleId, isNotNull);

      final RecurrenceRule? rule = await readDb(
        tester,
        () => recurrence.findForTask(rows.single.id),
      );
      expect(rule!.frequency, RecurrenceFrequency.weekly);
      // 没设过日期，锚点就是补上的今天（本地零点）。
      expect(rule.startsOn, today());
      expect(find.text('首页占位'), findsOneWidget, reason: '存完就退回上一页');

      await closeDatabase(tester);
    });
  });

  group('编辑已有的重复任务', () {
    testWidgets('区块显示规则摘要，去掉截止日期会连重复一起取消', (WidgetTester tester) async {
      final String id = await seedTask(anchor: today());
      await pumpEditor(tester, taskId: id);

      expect(find.text('每天'), findsOneWidget);
      expect(find.textContaining('下一次：'), findsOneWidget);

      await tester.tap(find.byTooltip('清除截止时间'));
      await tester.pumpAndSettle();

      expect(find.text('去掉截止日期，重复也就一起取消了。'), findsOneWidget);
      expect(find.text('不重复'), findsOneWidget);
      expect(find.text('设置重复'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('规则没读完之前，区块说在读，保存按钮是灰的', (WidgetTester tester) async {
      final String id = await seedTask(anchor: today());
      stuck = _StuckRecurrence(db);

      await pumpEditor(tester, taskId: id);

      expect(find.text('正在读取重复设置…'), findsOneWidget);
      expect(find.text('不重复'), findsNothing, reason: '还不知道有没有规则');
      expect(saveEnabled(tester), isFalse);

      final RecurrenceRule? loaded = await readDb(
        tester,
        () => RecurrenceRepository(db).findForTask(id),
      );
      stuck!.gate.complete(loaded);
      await tester.pumpAndSettle();

      expect(find.text('正在读取重复设置…'), findsNothing);
      expect(find.text('每天'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);

      await closeDatabase(tester);
    });

    testWidgets('改了重复设置，保存前先问作用范围', (WidgetTester tester) async {
      final String id = await seedTask(anchor: today());
      await pumpEditor(tester, taskId: id);

      await openSheet(tester, find.text('每天'));
      await tester.tap(find.widgetWithText(ChoiceChip, '每周'));
      await tester.pumpAndSettle();
      await saveSheet(tester);
      expect(find.text('每天'), findsNothing, reason: '区块已经换成新设置');

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.text('改动应用到哪？'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '此后全部'));
      await tester.pumpAndSettle();

      final RecurrenceRule? rule = await readDb(
        tester,
        () => recurrence.findForTask(id),
      );
      expect(rule!.frequency, RecurrenceFrequency.weekly);
      expect(find.text('首页占位'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('「此后全部」把系列锚点挪到新的日期，「仅此一次」不动它', (WidgetTester tester) async {
      // 这一条被挪到了两天后：锚点还在今天，实例已经不在节奏上了。
      final DateTime moved = fromUtcMillis(
        dayOnlyMillis(DateTime.now().add(const Duration(days: 2))),
      );
      final String id = await seedTask(anchor: today(), due: moved);
      await pumpEditor(tester, taskId: id);

      await openSheet(tester, find.text('每天'));
      await tester.tap(find.widgetWithText(ChoiceChip, '每周'));
      await tester.pumpAndSettle();
      await saveSheet(tester);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '仅此一次'));
      await tester.pumpAndSettle();

      final RecurrenceRule? kept = await readDb(
        tester,
        () => recurrence.findForTask(id),
      );
      expect(kept!.frequency, RecurrenceFrequency.weekly);
      expect(kept.startsOn, today(), reason: '锚点原样放回去，这一条会被吸回原节奏');

      // 再来一次，这回选「此后全部」。没挑过星期几，摘要里的日子是锚点那天。
      await pumpEditor(tester, taskId: id);
      await openSheet(tester, find.text('每周${_weekdayOf(today())}'));
      await tester.tap(find.widgetWithText(ChoiceChip, '每月'));
      await tester.pumpAndSettle();
      await saveSheet(tester);
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '此后全部'));
      await tester.pumpAndSettle();

      final RecurrenceRule? moved2 = await readDb(
        tester,
        () => recurrence.findForTask(id),
      );
      expect(moved2!.frequency, RecurrenceFrequency.monthly);
      expect(moved2.startsOn, moved, reason: '锚点跟着这一条的日期走');

      await closeDatabase(tester);
    });

    testWidgets('取消重复：区块回到「不重复」，保存之后规则行没了', (WidgetTester tester) async {
      final String id = await seedTask(anchor: today());
      await pumpEditor(tester, taskId: id);

      await tester.tap(find.byTooltip('取消重复'));
      await tester.pumpAndSettle();
      expect(find.text('不重复'), findsOneWidget);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '此后全部'));
      await tester.pumpAndSettle();

      expect(await readDb(tester, () => recurrence.findForTask(id)), isNull);
      expect(
        await readDb(tester, () => tasks.findById(id)),
        isNotNull,
        reason: '历史实例不该被连坐',
      );
      expect(find.text('首页占位'), findsOneWidget);

      await closeDatabase(tester);
    });
  });
}

/// 锚点那一天是星期几，用来写「每周X」的断言。
String _weekdayOf(DateTime date) =>
    const <String>['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];
