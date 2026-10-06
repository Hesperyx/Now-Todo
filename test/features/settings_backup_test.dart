// 设置页「数据」区块的用例：用户按下去之后会发生什么。
//
// 格式与落库口径分别在 `test/core/backup/backup_codec_test.dart` 和
// `test/data/backup_repository_test.dart` 里咬；这里守的是**流程**——选文件失败
// 会不会把库弄脏、确认框取消之后是不是真的什么都没发生、导入的结果有没有说出来。
//
// 文件服务换成假实现：真的 `file_picker` / `share_plus` 在测试里既没有平台通道，
// 也没法断言「到底递出去了什么」。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/backup/backup_codec.dart';
import 'package:now_todo/core/backup/backup_model.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/data/backup/backup_file_service.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/settings/settings_page.dart';

import '../helpers/recording_notification_service.dart';
import '../helpers/test_database.dart';

/// 只记账、不碰磁盘的文件服务。
class FakeFileService implements BackupFileService {
  /// 下一次 [share] 收到的文本与文件名。
  String? shared;
  String? sharedFileName;
  String? sharedSubject;

  /// 下一次 [pickText] 返回什么；`null` 表示用户在系统选择器里点了取消。
  String? pick;

  /// 非空则对应的方法抛这个错误。
  Object? shareError;
  Object? pickError;

  @override
  Future<void> share(
    String text, {
    required String fileName,
    String? subject,
  }) async {
    final Object? error = shareError;
    if (error != null) throw error;
    shared = text;
    sharedFileName = fileName;
    sharedSubject = subject;
  }

  @override
  Future<String?> pickText() async {
    final Object? error = pickError;
    if (error != null) throw error;
    return pick;
  }
}

void main() {
  late AppDatabase db;
  late FakeFileService files;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    files = FakeFileService();
  });

  /// 读库：drift 的 future 要在真实的事件循环里落地。
  Future<T> readDb<T>(WidgetTester tester, Future<T> Function() action) async {
    return (await tester.runAsync(action)) as T;
  }

  /// 关库。**必须放在用例体的最后一步**，理由见 `test/widget_test.dart` 的长注释。
  Future<void> closeDatabase(WidgetTester tester) async {
    await tester.runAsync(db.close);
  }

  /// 手搓一份只有一条任务的备份文件文本。
  String fileWithTask(String title) => encodeBackup(
    BackupData(
      exportedAt: 1760000000000,
      app: const BackupAppInfo(
        name: 'now_todo',
        version: 'test',
        schemaVersion: 4,
      ),
      taskLists: const <BackupListRow>[],
      tags: const <BackupTagRow>[],
      tasks: <BackupTaskRow>[
        BackupTaskRow(
          id: 'task-from-file',
          title: title,
          note: null,
          dueDate: null,
          dueDateHasTime: false,
          priority: 0,
          status: 0,
          listId: null,
          recurrenceRuleId: null,
          createdAt: 1000,
          updatedAt: 1000,
          completedAt: null,
          estimatedPomodoros: null,
        ),
      ],
      taskTags: const <BackupTaskTagRow>[],
      subtasks: const <BackupSubtaskRow>[],
      reminders: const <BackupReminderRow>[],
      recurrenceRules: const <BackupRecurrenceRow>[],
      focusSessions: const <BackupFocusSessionRow>[],
      settings: const AppPreferences(),
    ),
  );

  Future<void> pumpPage(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/settings',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('首页占位'))),
        ),
        GoRoute(
          path: '/about',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('关于占位'))),
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          backupFileServiceProvider.overrideWithValue(files),
          // 版本号平时要问插件，而测试里那条平台通道没有对端——await 会一直挂着。
          appVersionProvider.overrideWith((Ref ref) async => '1.0.0+1'),
          // 通知那一段是真实平台能力：换成记账的实现，省得测试里到处缺平台通道。
          notificationServiceProvider.overrideWithValue(
            RecordingNotificationService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 设置页是一整条 ListView，「数据」区块在下面，点之前先滚到看得见。
  Future<void> tapItem(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<List<String>> loadTitles(WidgetTester tester) =>
      readDb(tester, () async {
        final List<Task> rows = await db.select(db.tasks).get();
        return <String>[for (final Task row in rows) row.title];
      });

  group('导出', () {
    testWidgets('把库里的东西写进文件递出去，并说一声', (WidgetTester tester) async {
      await readDb(tester, () => TaskRepository(db).create(title: '交周报'));
      await pumpPage(tester);

      await tapItem(tester, '导出数据');

      expect(files.shared, isNotNull);
      final BackupData written = decodeBackup(files.shared!);
      expect(written.tasks.single.title, '交周报');
      expect(written.taskLists.single.id, isNotNull);
      expect(files.sharedFileName, startsWith('now-todo-backup-'));
      expect(files.sharedFileName, endsWith('.json'));
      expect(files.sharedSubject, contains('Now Todo'));
      expect(find.textContaining('备份已生成'), findsOneWidget);

      await closeDatabase(tester);
    });

    testWidgets('文件写不出来时，错误照实说', (WidgetTester tester) async {
      await pumpPage(tester);
      files.shareError = const BackupFileException('写不出备份文件：磁盘满了');

      await tapItem(tester, '导出数据');

      expect(files.shared, isNull);
      expect(find.textContaining('导出失败'), findsOneWidget);
      expect(find.textContaining('磁盘满了'), findsOneWidget);

      await closeDatabase(tester);
    });
  });

  group('导入', () {
    testWidgets('文件读不出来：给出人话，库一点没动', (WidgetTester tester) async {
      await readDb(tester, () => TaskRepository(db).create(title: '本地原有的'));
      await pumpPage(tester);
      files.pick = '这不是 JSON';

      await tapItem(tester, '导入数据');

      expect(find.textContaining('不是合法的 JSON'), findsOneWidget);
      expect(find.text('怎么导入？'), findsNothing);
      expect(await loadTitles(tester), <String>['本地原有的']);

      await closeDatabase(tester);
    });

    testWidgets('用户在选择器里点取消：什么都不问，也不说', (WidgetTester tester) async {
      await pumpPage(tester);
      files.pick = null;

      await tapItem(tester, '导入数据');

      expect(find.text('怎么导入？'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      await closeDatabase(tester);
    });

    testWidgets('合并导入：只补本地没有的，并把结果说出来', (WidgetTester tester) async {
      await readDb(tester, () => TaskRepository(db).create(title: '本地原有的'));
      await pumpPage(tester);
      files.pick = fileWithTask('文件里的任务');

      await tapItem(tester, '导入数据');
      expect(find.text('怎么导入？'), findsOneWidget);
      expect(find.textContaining('文件里有 1 条任务'), findsOneWidget);

      await tester.tap(find.text('合并导入'));
      await tester.pumpAndSettle();

      expect(find.textContaining('合并导入完成'), findsOneWidget);
      expect(
        await loadTitles(tester),
        containsAll(<String>['本地原有的', '文件里的任务']),
      );

      await closeDatabase(tester);
    });

    testWidgets('覆盖导入：本地独有的东西跟着没了', (WidgetTester tester) async {
      await readDb(tester, () => TaskRepository(db).create(title: '本地原有的'));
      await pumpPage(tester);
      files.pick = fileWithTask('文件里的任务');

      await tapItem(tester, '导入数据');
      await tester.tap(find.text('覆盖导入'));
      await tester.pumpAndSettle();

      expect(find.textContaining('覆盖导入完成'), findsOneWidget);
      expect(await loadTitles(tester), <String>['文件里的任务']);

      await closeDatabase(tester);
    });

    testWidgets('确认框里点取消：文件已经在手上，也不写库', (WidgetTester tester) async {
      await readDb(tester, () => TaskRepository(db).create(title: '本地原有的'));
      await pumpPage(tester);
      files.pick = fileWithTask('文件里的任务');

      await tapItem(tester, '导入数据');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(await loadTitles(tester), <String>['本地原有的']);

      await closeDatabase(tester);
    });
  });
}
