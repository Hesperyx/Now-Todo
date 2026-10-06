import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/app/app.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/app/router.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/notifications/notification_service.dart';
import 'package:now_todo/core/theme/app_theme.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/settings_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

/// 深色模式走查里能机械验的那一半。
///
/// 「有没有哪个角落还是浅色的」最终得靠眼睛，但有两件事必须先由测试守住：
/// 偏好落成深色之后整个应用真的切过去了，以及每个页面在深色下都能画出来。
/// 后者漏掉的典型症状不是崩溃，是某处用了写死的浅色，文本在深色底上消失。
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late String taskId;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();

    // 深色不是测试硬塞给 `MaterialApp` 的参数，而是「用户选过、已经落库」的状态：
    // 走真实路径（偏好 → `preferencesProvider` → `themeMode`）。
    await SettingsRepository(
      db,
    ).update(themeMode: ThemeModeSetting.dark, defaultView: DefaultView.all);

    final TaskRepository tasks = TaskRepository(db);
    taskId = await tasks.create(
      title: '深色模式下的任务',
      note: '备注也要看得清',
      dueDate: dayOnlyMillis(DateTime.now()),
      priority: TaskPriority.high,
    );
    await tasks.setTaskTags(taskId, <String>['工作']);
    await tasks.addSubtask(taskId, '打包');

    container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          const NoopNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  /// 手动推帧而不是 `pumpAndSettle`：计时相关的页面有每秒重绘，
  /// 帧永远排不空。30 × 16ms 够所有进场动画跑完。
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NowTodoApp(),
      ),
    );
    await settle(tester);
  }

  /// 关库必须在用例体里、并且是最后一步（理由见 `test/widget_test.dart`）。
  Future<void> closeDatabase(WidgetTester tester) => tester.runAsync(db.close);

  testWidgets('深色偏好落库之后，应用真的切到了深色', (WidgetTester tester) async {
    await pumpApp(tester);

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final ThemeData theme = Theme.of(context);

    expect(theme.brightness, Brightness.dark);
    expect(
      theme.scaffoldBackgroundColor,
      AppTheme.dark().scaffoldBackgroundColor,
      reason: '底色应当是深色主题那一份，不是浅色的',
    );
    // 深色的底色本身要比浅色暗，否则「切过去了」只是名义上的。
    expect(
      theme.scaffoldBackgroundColor.computeLuminance(),
      lessThan(AppTheme.light().scaffoldBackgroundColor.computeLuminance()),
    );

    await closeDatabase(tester);
  });

  testWidgets('八个页面在深色下都画得出来', (WidgetTester tester) async {
    await pumpApp(tester);

    final List<(String, String)> pages = <(String, String)>[
      (AppRoutes.home, '深色模式下的任务'),
      (AppRoutes.taskNew, '新建任务'),
      (AppRoutes.taskDetail(taskId), '编辑任务'),
      (AppRoutes.settings, '设置'),
      (AppRoutes.about, '关于'),
      (AppRoutes.lists, '清单'),
      (AppRoutes.tags, '标签'),
      (AppRoutes.focus, '专注'),
    ];

    for (final (String route, String expected) in pages) {
      container.read(appRouterProvider).go(route);
      await settle(tester);

      expect(tester.takeException(), isNull, reason: '$route 在深色下抛了异常');
      expect(
        find.text(expected),
        findsWidgets,
        reason: '$route 没有画出「$expected」',
      );
      expect(
        Theme.of(tester.element(find.text(expected).first)).brightness,
        Brightness.dark,
        reason: '$route 拿到的不是深色主题',
      );
    }

    await closeDatabase(tester);
  });

  testWidgets('首页的任务卡片在深色下把该显示的都显示了', (WidgetTester tester) async {
    await pumpApp(tester);

    // 优先级、标签、日期、子任务进度都各自取色，最容易漏掉其中一处。
    expect(find.text('深色模式下的任务'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);

    await closeDatabase(tester);
  });
}
