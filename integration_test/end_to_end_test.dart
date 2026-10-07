// 真机端的到端验证（M8 验收第一条）。
//
// 单元测试与 widget 测试跑在假的时钟与内存库上，证明不了「装到手机上从冷启动
// 一路点下去还成立」。这里补上那一段：跑**真实的**启动路径（`app.main()` 的
// 真数据库、真通知、真时区），只把碰系统 UI 的部件换掉——分享面板在自动化里
// 点不到，所以 `backupFileServiceProvider` 换成记录用的假实现，其余全真。
//
// 跑法（需要设备在线，`flutter devices` 能看到）：
//
//   adb install -r -g -d build\app\outputs\flutter-apk\app-debug.apk   # -g 顺手给通知权限
//   flutter test integration_test/end_to_end_test.dart -d <deviceId>
//
// 先授权的那一步与 `reminder_delivery_test.dart` 同理：系统弹窗在自动化里点不到。
// 有些 ROM 收掉了 shell 的 `GRANT_RUNTIME_PERMISSIONS`，`adb shell pm grant …` 会抛
// `SecurityException`，这时 `adb install -g` 是唯一的路子（实测 `PLQ110` 就是这样）。
// 这条用例会往设备的真实数据库里写数据，结束时自己清掉（任务、标签、提醒与
// 已排的通知都会删掉）；中途失败时可能留下 `e2e-` 开头的一条任务，手动删即可。

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:now_todo/app/providers.dart';
import 'package:now_todo/core/backup/backup_codec.dart';
import 'package:now_todo/core/backup/backup_model.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/notifications/notification_ids.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/backup/backup_file_service.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/backup_repository.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/reminder_repository.dart';
import 'package:now_todo/data/repositories/settings_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:now_todo/features/home/widgets/task_tile.dart';
import 'package:now_todo/main.dart' as app;
import 'package:path_provider/path_provider.dart';

/// 记录「分享出去的是什么」，不真的打开分享面板。
class _RecordingFileService implements BackupFileService {
  String? shared;
  String? sharedFileName;
  String? picked;

  @override
  Future<void> share(
    String text, {
    required String fileName,
    String? subject,
  }) async {
    shared = text;
    sharedFileName = fileName;
  }

  @override
  Future<String?> pickText() async => picked;
}

/// 等系统真的收下这条排程。
///
/// 库变化 → 调度器重排 → 平台通道，中间隔着几次异步跳跃；手机上这几拍通常在
/// 百毫秒级，但不是同步完成的，所以轮询而不是断言一次。
Future<List<PendingNotificationRequest>> _waitForPending(
  WidgetTester tester,
  int notificationId, {
  Duration limit = const Duration(seconds: 15),
}) async {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  final DateTime deadline = DateTime.now().add(limit);
  List<PendingNotificationRequest> pending = await plugin
      .pendingNotificationRequests();
  while (DateTime.now().isBefore(deadline) &&
      !pending.any(
        (PendingNotificationRequest item) => item.id == notificationId,
      )) {
    await tester.pump(const Duration(milliseconds: 200));
    pending = await plugin.pendingNotificationRequests();
  }
  return pending;
}

/// 把目标滚进视口。
///
/// 表单比屏幕长，而 `ListView` 只挂载视口附近的子节点：还没挂载的控件 `find` 根本
/// 匹配不到（`enterText` 会抛 `Bad state: No element`），所以「先滚到它」是这类断言
/// 的必要前置。
///
/// 实现上先一路滚回顶部再往下找，而不是从当前位置朝某个方向猜：写字的动作本身会
/// 改变滚动位置（实测：焦点离开输入框之后表单会弹回顶部），起点不可依赖。
///
/// 找不到就静默返回，把报错留给调用方的 `expect`——那里的 `reason` 能说清是什么
/// 控件、当时挂了哪些，比 `scrollUntilVisible` 抛的 `StateError` 好读。
Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  int maxSteps = 25,
}) async {
  final Finder viewport = find.byType(Scrollable).first;
  for (int step = 0; step < 12; step++) {
    await tester.drag(viewport, const Offset(0, 600));
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
  }
  for (int step = 0; step < maxSteps; step++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(viewport, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

/// 往指定标签的输入框里写字，必要时先滚到它。
Future<void> _enterField(WidgetTester tester, String label, String text) async {
  final Finder field = find.widgetWithText(TextField, label);
  await _scrollTo(tester, field);
  expect(
    field,
    findsOneWidget,
    reason:
        '表单里应该有「$label」输入框；当前挂载的输入框：'
        '${tester.widgetList<TextField>(find.byType(TextField)).map((TextField item) => item.decoration?.labelText ?? '?').join('、')}',
  );
  await tester.enterText(field, text);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 这两条用例会各开一个 `AppDatabase`，drift 为此会打印一条「同一个库被开了
    // 多次」的警告并附上调用栈。这里是测试故意为之（一条用真库、一条用内存库），
    // 按文档把这条噪音关掉。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('冷启动 → 建任务 → 加标签 → 设提醒 → 完成 → 导出', (WidgetTester tester) async {
    final _RecordingFileService files = _RecordingFileService();
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String title = 'e2e-任务-$stamp';
    final String tag = 'e2e-标签-$stamp';

    // 真实启动路径，只换掉分享面板那一层。
    await app.main(
      overrides: <Override>[backupFileServiceProvider.overrideWithValue(files)],
    );
    await tester.pumpAndSettle();

    // 1. 冷启动后停在首页。
    expect(find.text('新建'), findsOneWidget, reason: '首页的新建入口');

    // 2. 建一条任务，顺手挂一个标签。
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    await _enterField(tester, '标题', title);
    await _enterField(tester, '添加标签', tag);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // 胶囊加在输入框**上方**，而现在视口可能已经不在那里，先滚过去再看。
    await _scrollTo(tester, find.widgetWithText(InputChip, tag));
    expect(
      find.widgetWithText(InputChip, tag),
      findsOneWidget,
      reason:
          '标签要变成胶囊才算加上了；当前挂载的输入框：'
          '${tester.widgetList<TextField>(find.byType(TextField)).map((TextField item) => '${item.decoration?.labelText}=「${item.controller?.text ?? ''}」').join('、')}；'
          '挂载中的胶囊：'
          '${tester.widgetList<InputChip>(find.byType(InputChip)).map((InputChip item) => (item.label as Text).data ?? '?').join('、')}',
    );

    await _scrollTo(tester, find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 3. 回首页，切到「全部」能找到它（新任务没有截止日期，「今天」里不显示）。
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    // 库里可能已经躺着别的任务，新任务不一定在首屏里被挂载，先滚到它。
    await _scrollTo(tester, find.text(title));
    expect(find.text(title), findsOneWidget);
    expect(find.text(tag), findsWidgets, reason: '任务行上要带上标签');

    // 4. 从库里取出这条任务的 id：串起「界面写入」与「系统排程」需要它。
    final AppDatabase db = AppDatabase();
    await db.ensureInitialized();
    final List<Task> rows = await db.select(db.tasks).get();
    final Task task = rows.firstWhere((Task row) => row.title == title);

    // 5. 加一条提醒。
    //
    // 这里不走界面的时间选择器：那是系统对话框里拨表盘，自动化价值低、脆性高。
    // 端到端真正要证明的是「一条提醒进库之后，系统里真的多了一个闹钟」，
    // 所以从仓储写、再问系统要结果——中间那一段（库变化 → 调度器 → 平台通道）
    // 全是真代码。
    final ReminderRepository reminders = ReminderRepository(db);
    final String reminderId = await reminders.add(
      taskId: task.id,
      remindAt: DateTime.now().add(const Duration(minutes: 3)).utcMillis,
    );
    final int notificationId = NotificationIds.forReminder(reminderId);
    final List<PendingNotificationRequest> pending = await _waitForPending(
      tester,
      notificationId,
    );
    expect(
      pending.map((PendingNotificationRequest item) => item.id),
      contains(notificationId),
      reason: '库里有提醒之后，系统里必须真的排上一条；没排上说明权限或调度断了',
    );

    // 6. 完成它。
    await _scrollTo(tester, find.text(title));
    final Finder tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(TaskTile),
    );
    expect(tile, findsOneWidget);
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(title));
    expect(find.text(title), findsOneWidget, reason: '勾完之后应当落在「已完成」里');

    // 7. 导出：设置 → 数据 → 导出数据。
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('导出数据'));
    expect(
      find.text('导出数据'),
      findsOneWidget,
      reason: '设置页里应该有导出入口（列表只挂载视口附近的条目，一路滚到底还没出现就是真没有）',
    );
    await tester.tap(find.text('导出数据'));
    await tester.pumpAndSettle();

    expect(files.shared, isNotNull, reason: '导出应当把 JSON 交给文件服务');
    expect(files.sharedFileName, endsWith('.json'));
    final BackupData exported = decodeBackup(files.shared!);
    expect(
      exported.tasks.map((BackupTaskRow row) => row.title),
      contains(title),
      reason: '刚建的任务必须在导出文件里',
    );
    expect(exported.tags.map((BackupTagRow row) => row.name), contains(tag));
    expect(
      exported.reminders.map((BackupReminderRow row) => row.taskId),
      contains(task.id),
      reason: '刚加的提醒也要在文件里',
    );

    // 清场：这条用例写的是设备上的真库，别留下垃圾。
    await FlutterLocalNotificationsPlugin().cancel(id: notificationId);
    await TaskRepository(db).delete(task.id);
    final List<TodoTag> tags = await TagRepository(db).watch().first;
    for (final TodoTag item in tags.where((TodoTag it) => it.name == tag)) {
      await TagRepository(db).delete(item.id);
    }
    await db.close();
  });

  // 这一条不碰界面，只需要真文件系统，所以是普通 `test()`。
  test('导出的 JSON 落到真文件再读回来，能整份导进另一个库', () async {
    final AppDatabase source = AppDatabase();
    await source.ensureInitialized();
    final BackupRepository backup = BackupRepository(
      source,
      SettingsRepository(source),
    );

    final BackupData data = await backup.export(appVersion: '1.0.0+1');
    final Directory dir = await getTemporaryDirectory();
    final File file = File(
      '${dir.path}${Platform.pathSeparator}now-todo-e2e.json',
    );
    await file.writeAsString(encodeBackup(data), flush: true);
    expect(await file.length(), greaterThan(0));

    final BackupData readBack = decodeBackup(await file.readAsString());
    expect(readBack.exportedAt, data.exportedAt);
    expect(readBack.tasks.length, data.tasks.length);

    // 导进一个全新的空库：覆盖模式，落完应当与文件一致。
    final AppDatabase target = AppDatabase.forTesting(NativeDatabase.memory());
    await target.ensureInitialized();
    final ImportOutcome outcome = await BackupRepository(
      target,
      SettingsRepository(target),
    ).importData(readBack, mode: ImportMode.overwrite);
    expect(outcome.mode, ImportMode.overwrite);

    final List<Task> targetTasks = await target.select(target.tasks).get();
    expect(targetTasks.length, data.tasks.length);
    // 还没结束的会话不会被搬过去（见 `BackupRepository.importData` 的说明：一段
    // 在跑的会话属于那台设备的当前状态，不是历史），所以比的是已结束的那些。
    // 手机上恰好有一段倒计时在跑时，这两个数字会不一样——这正是要断言的。
    final int finished = data.focusSessions
        .where((BackupFocusSessionRow row) => row.endedAt != null)
        .length;
    final int inFlight = data.focusSessions.length - finished;
    final List<FocusSession> targetSessions = await target
        .select(target.focusSessions)
        .get();
    expect(targetSessions.length, finished);
    if (inFlight > 0) {
      expect(outcome.skipped['focusSessions'], inFlight);
    }

    await file.delete();
    await source.close();
    await target.close();
  });
}
