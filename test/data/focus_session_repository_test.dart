import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/focus/focus_timer.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';
import 'package:now_todo/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FocusSessionRepository sessions;
  late TaskRepository tasks;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    sessions = FocusSessionRepository(db);
    tasks = TaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 用例一律用固定的「2030 年」时刻，不依赖真实时间。
  final DateTime t0 = DateTime(2030, 5, 1, 9);
  final int d0 = dayOnlyMillis(DateTime(2030, 5, 1));
  final int d1 = dayOnlyMillis(DateTime(2030, 5, 2));

  group('开始与读取', () {
    test('排一条会话之后读得回来，字段都在', () async {
      final String id = await sessions.start(
        at: t0,
        logicalDate: d0,
        kind: FocusSessionKind.focus,
        plan: const Duration(minutes: 25),
      );

      final TodoFocusSession? row = await sessions.running();
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.startedAt, t0.utcMillis);
      expect(row.logicalDate, d0);
      expect(row.plannedSeconds, 1500);
      expect(row.actualSeconds, 0);
      expect(row.pausedMillis, 0);
      expect(row.pausedAt, isNull);
      expect(row.kind, FocusSessionKind.focus);
      expect(row.timerMode, FocusTimerMode.countDown);
      expect(row.completed, isFalse);
      expect(row.note, isNull);
      expect(row.isRunning, isTrue);
      expect(row.isPaused, isFalse);
    });

    test('不给计划时长时用默认的 25 分钟', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final TodoFocusSession row = (await sessions.running())!;
      expect(row.plannedSeconds, FocusTimerState.defaultPlan.inSeconds);
    });

    test('正计时不记计划时长，带上 plan 会被断言拦住', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        mode: FocusTimerMode.countUp,
      );
      final TodoFocusSession row = (await sessions.running())!;
      expect(row.plannedSeconds, isNull);
      expect(row.timerMode, FocusTimerMode.countUp);

      await expectLater(
        sessions.start(
          at: t0,
          logicalDate: d0,
          mode: FocusTimerMode.countUp,
          plan: const Duration(minutes: 5),
        ),
        throwsAssertionError,
      );
    });

    test('休息也是一条会话，不折成专注', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        kind: FocusSessionKind.shortBreak,
        plan: const Duration(minutes: 5),
      );
      final TodoFocusSession row = (await sessions.running())!;
      expect(row.kind, FocusSessionKind.shortBreak);
      expect(row.plannedSeconds, 300);
    });

    test('没有任何会话时 running 是 null，unfinished 是空的', () async {
      expect(await sessions.running(), isNull);
      expect(await sessions.unfinished(), isEmpty);
    });

    test('按逻辑日取会话：闭区间，隔天的不混进来', () async {
      await sessions.start(at: t0, logicalDate: d0);
      await sessions.finish(
        (await sessions.running())!.id,
        at: t0.add(const Duration(minutes: 25)),
      );
      await sessions.start(at: DateTime(2030, 5, 2, 9), logicalDate: d1);
      await sessions.finish(
        (await sessions.running())!.id,
        at: DateTime(2030, 5, 2, 9, 25),
      );

      expect((await sessions.listBetween(from: d0, to: d0)).length, 1);
      expect((await sessions.listBetween(from: d0, to: d1)).length, 2);
      // 闭区间：只问第二天也拿得到第二天那条。
      expect(
        (await sessions.listBetween(from: d1, to: d1)).single.logicalDate,
        d1,
      );
    });

    test('归属任务能带上，任务被删之后会话历史保留、taskId 置空', () async {
      final String taskId = await tasks.create(title: '写方案');
      await sessions.start(at: t0, logicalDate: d0, taskId: taskId);
      expect((await sessions.running())!.taskId, taskId);

      await tasks.delete(taskId);

      final TodoFocusSession row = (await sessions.running())!;
      expect(row.taskId, isNull, reason: 'ON DELETE SET NULL，不是级联删除');
      expect(await sessions.listBetween(from: d0, to: d0), hasLength(1));
    });
  });

  group('不变式：最多一条未结束', () {
    test('再开一条会把上一条收掉，停在新的开始时刻', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final DateTime t1 = t0.add(const Duration(minutes: 30));
      await sessions.start(at: t1, logicalDate: d0);

      final List<TodoFocusSession> open = await sessions.unfinished();
      expect(open, hasLength(1), reason: '僵尸会话必须被收掉');

      final TodoFocusSession closed = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).firstWhere((TodoFocusSession s) => s.id != open.single.id);
      expect(closed.endedAt, t1.utcMillis);
      expect(closed.actualSeconds, 1800, reason: '被取代的那一段是真实发生过的时间，不能抹成 0');
    });

    test('被收掉的那条如果已经走满，仍然记成完成', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      await sessions.start(
        at: t0.add(const Duration(hours: 1)),
        logicalDate: d0,
      );

      final TodoFocusSession closed = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).firstWhere((TodoFocusSession s) => !s.isRunning);
      expect(closed.completed, isTrue);
      expect(closed.actualSeconds, 3600, reason: '实际时长照实记，不截到计划时长');
    });

    test('被收掉的那条正暂停着，时长停在暂停那一刻', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.pause(id, t0.add(const Duration(minutes: 10)));

      await sessions.start(
        at: t0.add(const Duration(hours: 2)),
        logicalDate: d0,
      );

      final TodoFocusSession closed = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).firstWhere((TodoFocusSession s) => !s.isRunning);
      expect(closed.actualSeconds, 600);
      expect(closed.pausedAt, isNull);
    });
  });

  group('暂停与恢复', () {
    test('暂停只写暂停时刻，累计暂停不动', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;

      await sessions.pause(id, t0.add(const Duration(minutes: 10)));

      final TodoFocusSession row = (await sessions.running())!;
      expect(row.pausedAt, t0.add(const Duration(minutes: 10)).utcMillis);
      expect(row.pausedMillis, 0);
      expect(row.isPaused, isTrue);
    });

    test('恢复把这段暂停累加进去，并清掉暂停时刻', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      final DateTime pausedAt = t0.add(const Duration(minutes: 10));
      await sessions.pause(id, pausedAt);
      await sessions.resume(id, pausedAt.add(const Duration(minutes: 20)));

      final TodoFocusSession row = (await sessions.running())!;
      expect(row.pausedAt, isNull);
      expect(row.pausedMillis, 20 * 60 * 1000);
    });

    test('暂停期间时长冻住，恢复后继续走', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.pause(id, t0.add(const Duration(minutes: 10)));

      final TodoFocusSession paused = (await sessions.running())!;
      expect(
        paused.elapsedSeconds(t0.add(const Duration(hours: 3))),
        600,
        reason: '暂停了一整个下午也不该算成专注',
      );

      await sessions.resume(id, t0.add(const Duration(hours: 3)));
      final TodoFocusSession resumed = (await sessions.running())!;
      expect(
        resumed.elapsedSeconds(t0.add(const Duration(hours: 3, minutes: 5))),
        900,
      );
    });

    test('暂停两次只记第一段，恢复之后才结算', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.pause(id, t0.add(const Duration(minutes: 10)));
      await sessions.pause(id, t0.add(const Duration(minutes: 30)));

      final TodoFocusSession row = (await sessions.running())!;
      expect(row.pausedAt, t0.add(const Duration(minutes: 10)).utcMillis);
      expect(row.pausedMillis, 0);
    });
  });

  group('结束', () {
    test('走满了就记成完成，实际时长按计划时长算', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      final String id = (await sessions.running())!.id;

      await sessions.finish(id, at: t0.add(const Duration(minutes: 25)));

      final TodoFocusSession row = (await sessions.watchDay(d0).first).single;
      expect(row.isRunning, isFalse);
      expect(row.completed, isTrue);
      expect(row.actualSeconds, 1500);
      expect(row.endedAt, t0.add(const Duration(minutes: 25)).utcMillis);
    });

    test('差一秒不算完成', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      final String id = (await sessions.running())!.id;
      await sessions.finish(
        id,
        at: t0.add(const Duration(minutes: 24, seconds: 59)),
      );

      final TodoFocusSession row = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).single;
      expect(row.completed, isFalse);
      expect(row.actualSeconds, 1499);
    });

    test('暂停中结束，时长停在暂停那一刻且清掉暂停时刻', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      final String id = (await sessions.running())!.id;
      await sessions.pause(id, t0.add(const Duration(minutes: 8)));
      await sessions.finish(id, at: t0.add(const Duration(hours: 1)));

      final TodoFocusSession row = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).single;
      expect(row.actualSeconds, 480);
      expect(row.pausedAt, isNull);
      expect(row.completed, isFalse);
    });

    test('正计时结束永远不算完成', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        mode: FocusTimerMode.countUp,
      );
      final String id = (await sessions.running())!.id;
      await sessions.finish(id, at: t0.add(const Duration(hours: 2)));

      final TodoFocusSession row = (await sessions.listBetween(
        from: d0,
        to: d0,
      )).single;
      expect(row.completed, isFalse);
      expect(row.actualSeconds, 7200);
    });

    test('结束之后它不再是 running', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.finish(id, at: t0.add(const Duration(minutes: 25)));
      expect(await sessions.running(), isNull);
      expect(await sessions.unfinished(), isEmpty);
    });

    test('findById 读到的是结束之后那一份，不是开始时的快照', () async {
      // 收尾弹层就靠这个：手里那个对象是开始那一刻的，actualSeconds 还是 0、
      // completed 还是 false，拿它去渲染就是「实际 00:00」。
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      final TodoFocusSession before = (await sessions.findById(id))!;
      expect(before.actualSeconds, 0);
      expect(before.completed, isFalse);

      await sessions.finish(id, at: t0.add(const Duration(minutes: 25)));

      final TodoFocusSession after = (await sessions.findById(id))!;
      expect(after.completed, isTrue);
      expect(after.actualSeconds, 25 * 60);
      expect(after.endedAt, isNotNull);
    });

    test('findById 读不到就是 null，不抛', () async {
      expect(await sessions.findById('没有这条'), isNull);
    });
  });

  group('改归属、改备注、撤销', () {
    test('能换任务，也能改回自由专注', () async {
      final String taskId = await tasks.create(title: '写方案');
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;

      await sessions.assignTask(id, taskId);
      expect((await sessions.running())!.taskId, taskId);

      await sessions.assignTask(id, null);
      expect((await sessions.running())!.taskId, isNull);
    });

    test('备注能写能清', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;

      await sessions.setNote(id, '思路断在第二段，明天重来');
      expect((await sessions.running())!.note, '思路断在第二段，明天重来');

      await sessions.setNote(id, null);
      expect((await sessions.running())!.note, isNull);
    });

    test('撤销是硬删除，历史里也不留', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.cancel(id);
      expect(await sessions.listBetween(from: d0, to: d0), isEmpty);
      expect(await sessions.unfinished(), isEmpty);
    });
  });

  group('崩溃恢复', () {
    test('杀进程之后重开能把会话取回来，用时按开始时刻连续算', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      final TodoFocusSession id = (await sessions.running())!;

      // 模拟进程被回收：什么都不做，直接重新读一遍库。
      final TodoFocusSession? recovered = await sessions.running();
      expect(recovered, isNotNull);
      expect(recovered!.id, id.id);
      expect(
        recovered.elapsedSeconds(t0.add(const Duration(minutes: 42))),
        2520,
        reason: '界面上要显示 42 分钟，不是 0',
      );
      expect(
        recovered.toTimerState().isFinished(
          t0.add(const Duration(minutes: 42)),
        ),
        isTrue,
      );
    });

    test('崩溃前正暂停着，重开后依然冻在那一刻', () async {
      await sessions.start(at: t0, logicalDate: d0);
      final String id = (await sessions.running())!.id;
      await sessions.pause(id, t0.add(const Duration(minutes: 6)));

      final TodoFocusSession recovered = (await sessions.running())!;
      expect(recovered.isPaused, isTrue);
      expect(recovered.elapsedSeconds(t0.add(const Duration(hours: 5))), 360);
    });
  });

  group('统计切片', () {
    test('切片只取区间内的逻辑日，秒数取自实际时长', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      await sessions.finish(
        (await sessions.running())!.id,
        at: t0.add(const Duration(minutes: 25)),
      );
      await sessions.start(at: DateTime(2030, 5, 2, 9), logicalDate: d1);
      await sessions.finish(
        (await sessions.running())!.id,
        at: DateTime(2030, 5, 2, 9, 10),
      );

      final List<FocusSlice> slices = await sessions.slicesBetween(
        from: d0,
        to: d0,
        now: DateTime(2030, 5, 3),
      );

      expect(slices, hasLength(1));
      expect(slices.single.logicalDate, d0);
      expect(slices.single.startedAt, t0.utcMillis);
      expect(slices.single.seconds, 1500);
      expect(totalSeconds(slices), 1500);
    });

    test('正在跑的那条按 now 现算，不用库里还写着的 0', () async {
      await sessions.start(at: t0, logicalDate: d0);

      final List<FocusSlice> slices = await sessions.slicesBetween(
        from: d0,
        to: d0,
        now: t0.add(const Duration(minutes: 10)),
      );

      expect(slices.single.seconds, 600);
    });

    test('算出来的切片能直接喂给按天聚合', () async {
      await sessions.start(
        at: t0,
        logicalDate: d0,
        plan: const Duration(minutes: 25),
      );
      await sessions.finish(
        (await sessions.running())!.id,
        at: t0.add(const Duration(minutes: 25)),
      );
      await sessions.start(at: DateTime(2030, 5, 2, 9), logicalDate: d1);
      await sessions.finish(
        (await sessions.running())!.id,
        at: DateTime(2030, 5, 2, 9, 30),
      );

      final List<FocusSlice> slices = await sessions.slicesBetween(
        from: d0,
        to: d1,
        now: DateTime(2030, 5, 3),
      );

      expect(secondsByDay(slices), {d0: 1500, d1: 1800});
    });
  });
}
