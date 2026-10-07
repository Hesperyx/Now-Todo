// 演示数据播种入口：给商店截图与真机走查准备一份像样的库（`docs/STORE.md` §5）。
//
// 这不是产品代码，也不会进发布包——它只是一个 `flutter run -t` 的入口。
//
// 跑法（设备在线，`-d` 指定设备）：
//
//   flutter run -t tool/seed/main.dart -d <deviceId>
//   flutter run -t tool/seed/main.dart -d <deviceId> --dart-define=SEED_ACTION=clear
//
// 跑完把发布包换回去（同一把 debug 签名密钥，`-r` 保留数据）：
//
//   adb install -r -g build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
//
// 为什么不用集成测试播种：`flutter test integration_test/… -d <device>` 跑完会
// 卸载应用（flutter_tools 的 `integration_test_device.dart` 收尾时调
// `uninstallApp`），播进去的数据跟着一起没。`flutter run` 不卸载。
//
// 为什么不在界面上手点：截图必须是中文，而 `adb shell input text` 只认 ASCII；
// 直接在设备进程里调仓储写库比点几十次稳得多——也才造得出三个月的专注记录
// （统计页与年视图没有数据就是空页）。
//
// 写的是**应用那个真库**（同一个 applicationId、同一个 database 文件），
// 所以跑完启动应用就能看到。写入前先清一遍演示数据，重复跑不会翻倍。
//
// 「清空」按下面的常量表删：任务标题、清单名、标签名，外加全部专注记录与
// 重复规则。首次装机的库里没有真实记录；若哪天攒了真记录，别跑清空。

library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart' as core;
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/data/repositories/organization_repository.dart';
import 'package:now_todo/data/repositories/recurrence_repository.dart';
import 'package:now_todo/data/repositories/reminder_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';
import 'package:path_provider/path_provider.dart';

/// 演示清单。名字要出现在清单页与截图里，所以写得像真的。
const List<String> _demoLists = <String>['工作', '生活', '读书'];

/// 演示标签。用来演示标签胶囊与按标签筛选。
const List<String> _demoTags = <String>['深度工作', '沟通', '阅读', '运动'];

/// 演示任务的标题。清空时按这张表匹配——改标题要同步改这里。
const List<String> _demoTaskTitles = <String>[
  '过一遍提案的第三稿',
  '和设计对齐图标细节',
  '写本周复盘',
  '读 30 页《设计心理学》',
  '跑步 5 公里',
  '交这个月电费',
  '周一复盘上周进度',
];

/// 专注记录往前铺多少天。三个月的量能让年视图看起来是「在用」的。
const int _seedDays = 84;

/// 报告落到这个文件名（应用专属外部目录，`adb pull` 能直接拿）。
const String _reportFileName = 'seed-report.txt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String action = String.fromEnvironment(
    'SEED_ACTION',
    defaultValue: 'write',
  );

  String report;
  int code = 0;
  final AppDatabase db = AppDatabase();
  try {
    await db.ensureInitialized();
    report = action == 'clear'
        ? '演示数据已清空：${await _clearDemo(db)}。'
        : await _seed(db);
  } on Object catch (error, stack) {
    code = 1;
    report = '播种失败（SEED_ACTION=$action）：$error\n$stack';
  }
  await db.close();

  debugPrint('== 演示数据 == $report');
  await _writeReport(report);
  // 留一点时间让日志落到 logcat 与 `flutter run` 的控制台，再收工。
  await Future<void>.delayed(const Duration(milliseconds: 400));
  // 退出进程：`flutter run` 会跟着结束，但**不会**卸载应用。
  exit(code);
}

/// 写入演示数据，返回一行结论。
Future<String> _seed(AppDatabase db) async {
  final TaskRepository tasks = TaskRepository(db);
  final ListRepository lists = ListRepository(db);
  final ReminderRepository reminders = ReminderRepository(db);
  final FocusSessionRepository sessions = FocusSessionRepository(db);
  final RecurrenceRepository recurrences = RecurrenceRepository(db);

  final String cleared = await _clearDemo(db);

  // ── 清单与标签 ─────────────────────────────────────────────
  final String work = await lists.create('工作', color: 0xFF2E6B5E);
  final String life = await lists.create('生活', color: 0xFF4A6FA5);
  final String reading = await lists.create('读书', color: 0xFFB4714A);

  // ── 今天的任务 ─────────────────────────────────────────────
  final String proposal = await tasks.create(
    title: '过一遍提案的第三稿',
    note: '第三稿主要看时间线与预算两处，其余先不动。',
    dueDate: _at(0, 10).utcMillis,
    dueDateHasTime: true,
    priority: TaskPriority.high,
    listId: work,
  );
  await tasks.setTaskTags(proposal, <String>['深度工作']);
  final String done = await tasks.addSubtask(proposal, '标出待确认的三处');
  await tasks.addSubtask(proposal, '补一版时间线');
  await tasks.addSubtask(proposal, '重算预算的区间');
  await tasks.setSubtaskDone(done, true);
  // 这一条要撑起「任务详情」截图：子任务、截止时间、标签、提醒都齐。
  await reminders.add(taskId: proposal, remindAt: _at(0, 9, 45).utcMillis);

  final String align = await tasks.create(
    title: '和设计对齐图标细节',
    dueDate: _at(0, 14).utcMillis,
    dueDateHasTime: true,
    priority: TaskPriority.medium,
    listId: work,
  );
  await tasks.setTaskTags(align, <String>['沟通']);
  await reminders.add(taskId: align, remindAt: _at(0, 13, 45).utcMillis);

  final String review = await tasks.create(
    title: '写本周复盘',
    dueDate: _at(0, 20).utcMillis,
    dueDateHasTime: true,
    priority: TaskPriority.medium,
    listId: work,
  );
  await tasks.setTaskTags(review, <String>['深度工作']);

  final String book = await tasks.create(
    title: '读 30 页《设计心理学》',
    dueDate: _at(0, 21, 30).utcMillis,
    dueDateHasTime: true,
    listId: reading,
  );
  await tasks.setTaskTags(book, <String>['阅读']);

  // 已完成的一条：今日视图里要有「勾掉的东西」，别全是待办。
  final String run = await tasks.create(
    title: '跑步 5 公里',
    dueDate: _at(0, 7, 30).utcMillis,
    dueDateHasTime: true,
    listId: life,
  );
  await tasks.setTaskTags(run, <String>['运动']);
  await tasks.setCompleted(run, true);

  // 逾期一条：展示「逾期」这个状态。
  await tasks.create(
    title: '交这个月电费',
    dueDate: _at(1, 9).utcMillis,
    dueDateHasTime: true,
    priority: TaskPriority.high,
    listId: life,
  );

  // 重复一条：截图里要演示「仅此一次 / 此后全部」的改法。
  final DateTime monday = _nextMondayAt(9, 30);
  final String rule = await recurrences.create(
    core.RecurrenceRule(
      startsOn: monday,
      frequency: RecurrenceFrequency.weekly,
      byWeekday: const <int>{DateTime.monday},
    ),
  );
  final String weekly = await tasks.create(
    title: '周一复盘上周进度',
    dueDate: monday.utcMillis,
    dueDateHasTime: true,
    listId: work,
    recurrenceRuleId: rule,
  );
  await tasks.setTaskTags(weekly, <String>['沟通']);

  // ── 专注记录 ───────────────────────────────────────────────
  //
  // 固定随机种子：同样的代码播种出同样的历史，截图可复现。
  final Random random = Random(20261008);
  final DateTime now = DateTime.now();
  int sessionCount = 0;
  for (int back = _seedDays - 1; back >= 0; back--) {
    final DateTime day = _at(back, 0);
    // 最近一周天天有，更早的按「周一/二/四/六」这种真实节奏来。
    final bool active =
        back <= 7 || const <int>{1, 2, 4, 6}.contains(day.weekday);
    if (!active) continue;

    final int perDay = back <= 7 ? 2 : 1;
    for (int i = 0; i < perDay; i++) {
      final DateTime start = i == 0
          ? _at(back, 9, 20)
          // 第二段放在晚上，偶尔晚到 22 点后（点亮「夜猫子」）。
          : _at(back, random.nextInt(4) == 0 ? 22 : 20, 40);
      if (!start.isBefore(now)) continue;
      final int minutes = random.nextInt(8) == 0 ? 50 : 25;
      final String id = await sessions.start(
        at: start,
        logicalDate: logicalDateFor(start.utcMillis, midnightMode: false),
        taskId: i == 0 ? proposal : null,
        plan: Duration(minutes: minutes),
      );
      // 五分之一提前收手：历史里全是满分反而假。
      final bool walkedThrough = random.nextInt(5) != 0;
      await sessions.finish(
        id,
        at: start.add(
          Duration(minutes: walkedThrough ? minutes : minutes ~/ 2),
        ),
      );
      sessionCount++;
    }
  }

  return '演示数据已写入：清掉了 $cleared；'
      '清单 ${_demoLists.length} 个、任务 ${_demoTaskTitles.length} 条、'
      '专注记录 $sessionCount 条（近 $_seedDays 天）。';
}

/// 删掉上一次播种留下的东西。写入与清空都先走这一遍。
Future<String> _clearDemo(AppDatabase db) async {
  final TaskRepository tasks = TaskRepository(db);
  final ListRepository lists = ListRepository(db);
  final TagRepository tags = TagRepository(db);
  final FocusSessionRepository sessions = FocusSessionRepository(db);

  int removedTasks = 0;
  for (final Task row in await db.select(db.tasks).get()) {
    if (_demoTaskTitles.contains(row.title)) {
      await tasks.delete(row.id);
      removedTasks++;
    }
  }
  int removedLists = 0;
  for (final TodoList list in await lists.watch().first) {
    if (_demoLists.contains(list.name)) {
      if (await lists.delete(list.id)) removedLists++;
    }
  }
  int removedTags = 0;
  for (final TodoTag tag in await tags.watch().first) {
    if (_demoTags.contains(tag.name)) {
      await tags.delete(tag.id);
      removedTags++;
    }
  }
  // 任务删完再删规则：`tasks.recurrence_rule_id` 是外键。
  final int rules = (await db.select(db.recurrenceRules).get()).length;
  await db.delete(db.recurrenceRules).go();

  int removedSessions = 0;
  for (final FocusSession row in await db.select(db.focusSessions).get()) {
    await sessions.cancel(row.id);
    removedSessions++;
  }
  return '任务 $removedTasks 条、清单 $removedLists 个、标签 $removedTags 个、'
      '重复规则 $rules 条、专注记录 $removedSessions 条';
}

DateTime _at(int daysBack, int hour, [int minute = 0]) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysBack, hour, minute);
}

/// 下一个周一（今天就是周一则取今天）的 [hour] 点。
DateTime _nextMondayAt(int hour, [int minute = 0]) {
  final DateTime today = _at(0, 0);
  final int delta = (DateTime.monday - today.weekday + 7) % 7;
  return DateTime(today.year, today.month, today.day + delta, hour, minute);
}

/// 把结论也落成一个文件，方便 `adb pull` 回来看（日志有时会被刷掉）。
Future<void> _writeReport(String report) async {
  try {
    final Directory? dir = await getExternalStorageDirectory();
    if (dir == null) return;
    final String path = '${dir.path}/$_reportFileName';
    await File(path).writeAsString('$report\n');
    debugPrint('播种报告：$path');
  } on Object catch (error) {
    debugPrint('播种报告写文件失败：$error');
  }
}
