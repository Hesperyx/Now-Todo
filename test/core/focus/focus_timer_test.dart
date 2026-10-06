// 计时内核的用例。
//
// 这一层的全部要求可以概括成一句话：**同样的输入永远给同样的输出**。
// 计时器不在这里，UI 每秒拿 now 进来问一次就行。
//
// 之所以值得写这么多边界：这个内核错了不会崩，只会在用户锁屏回来之后
// 显示一个安静地错误的数字。

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_timer.dart';
import 'package:now_todo/core/models/enums.dart';

void main() {
  final DateTime start = DateTime(2026, 10, 7, 9);

  group('elapsed', () {
    test('只依赖传入的 now：同一个时刻问多少次都是同一个答案', () {
      final FocusTimerState state = FocusTimerState.started(at: start);

      expect(
        state.elapsed(start.add(const Duration(minutes: 7))),
        const Duration(minutes: 7),
      );
      expect(
        state.elapsed(start.add(const Duration(minutes: 7))),
        const Duration(minutes: 7),
      );
    });

    test('随时间单调不减', () {
      final FocusTimerState state = FocusTimerState.started(at: start);

      Duration previous = Duration.zero;
      // 步长要能整除 600，否则循环会在 595 秒收尾——那断言的就是 9 分 55 秒了。
      for (int seconds = 0; seconds <= 600; seconds += 5) {
        final Duration now = state.elapsed(
          start.add(Duration(seconds: seconds)),
        );
        expect(now, greaterThanOrEqualTo(previous));
        previous = now;
      }
      expect(previous, const Duration(minutes: 10));
    });

    test('刚开就问到，是零而不是负数', () {
      final FocusTimerState state = FocusTimerState.started(at: start);
      expect(state.elapsed(start), Duration.zero);
    });

    test('系统时钟往回跳时不返回负数', () {
      final FocusTimerState state = FocusTimerState.started(at: start);
      expect(
        state.elapsed(start.subtract(const Duration(hours: 2))),
        Duration.zero,
      );
    });

    test('两个字段完全相同的状态对象，行为完全一致', () {
      final FocusTimerState a = FocusTimerState.started(at: start);
      final FocusTimerState b = FocusTimerState.started(at: start);
      final DateTime now = start.add(const Duration(minutes: 3));

      expect(a.elapsed(now), b.elapsed(now));
      expect(a.remaining(now), b.remaining(now));
    });
  });

  group('暂停与恢复', () {
    test('暂停期间已用时长冻住', () {
      final FocusTimerState state = FocusTimerState.started(
        at: start,
      ).pause(start.add(const Duration(minutes: 10)));

      expect(state.isPaused, isTrue);
      expect(
        state.elapsed(start.add(const Duration(minutes: 10))),
        const Duration(minutes: 10),
      );
      // 一小时后回来，仍然是 10 分钟。
      expect(
        state.elapsed(start.add(const Duration(hours: 1))),
        const Duration(minutes: 10),
      );
    });

    test('恢复之后，暂停的时长不计入已用', () {
      final FocusTimerState state = FocusTimerState.started(at: start)
          .pause(start.add(const Duration(minutes: 10)))
          .resume(start.add(const Duration(minutes: 30)));

      expect(state.isPaused, isFalse);
      expect(state.pausedMillis, const Duration(minutes: 20));
      // 9:00 开始，9:40 时真实专注了 20 分钟。
      expect(
        state.elapsed(start.add(const Duration(minutes: 40))),
        const Duration(minutes: 20),
      );
    });

    test('多次暂停恢复之后累计时长正确', () {
      // 9:00 开始 → 9:10 暂停 → 9:30 恢复 → 9:50 暂停 → 10:00 恢复
      // 真正在跑的：10 + 20 = 30 分钟，到 10:10 再加 10 分钟 = 40 分钟。
      final FocusTimerState state = FocusTimerState.started(at: start)
          .pause(start.add(const Duration(minutes: 10)))
          .resume(start.add(const Duration(minutes: 30)))
          .pause(start.add(const Duration(minutes: 50)))
          .resume(start.add(const Duration(minutes: 60)));

      expect(state.pausedMillis, const Duration(minutes: 30));
      expect(state.pausedAt, isNull);
      expect(
        state.elapsed(start.add(const Duration(minutes: 70))),
        const Duration(minutes: 40),
      );
    });

    test('暂停中的那次暂停时长不会提前算进 pausedMillis', () {
      final FocusTimerState state = FocusTimerState.started(
        at: start,
      ).pause(start.add(const Duration(minutes: 10)));

      expect(state.pausedMillis, Duration.zero);
      // 恢复时才算：这里恢复了 20 分钟。
      final FocusTimerState resumed = state.resume(
        start.add(const Duration(minutes: 30)),
      );
      expect(resumed.pausedMillis, const Duration(minutes: 20));
    });

    test('连着暂停两次、没暂停就恢复，都是空操作', () {
      final FocusTimerState once = FocusTimerState.started(
        at: start,
      ).pause(start.add(const Duration(minutes: 5)));
      final FocusTimerState twice = once.pause(
        start.add(const Duration(minutes: 8)),
      );

      expect(twice.pausedAt, once.pausedAt);
      expect(twice.pausedMillis, Duration.zero);

      final FocusTimerState running = FocusTimerState.started(at: start);
      expect(
        running.resume(start.add(const Duration(minutes: 5))).pausedMillis,
        Duration.zero,
      );
    });

    test('恢复时刻早于暂停时刻（时钟跳了）不会让累计暂停变成负数', () {
      final FocusTimerState state = FocusTimerState.started(at: start)
          .pause(start.add(const Duration(minutes: 10)))
          .resume(start.add(const Duration(minutes: 8)));

      expect(state.pausedMillis, Duration.zero);
      expect(
        state.elapsed(start.add(const Duration(minutes: 20))),
        const Duration(minutes: 20),
      );
    });
  });

  group('倒计时', () {
    final FocusTimerState state = FocusTimerState.started(
      at: start,
      plan: const Duration(minutes: 25),
    );

    test('计划时长换算成秒，供落库用', () {
      expect(state.plannedSeconds, 1500);
    });

    test('差一秒没走满就不算完成', () {
      expect(
        state.remaining(start.add(const Duration(minutes: 24, seconds: 59))),
        const Duration(seconds: 1),
      );
      expect(
        state.isFinished(start.add(const Duration(minutes: 24, seconds: 59))),
        isFalse,
      );
    });

    test('刚好走满算完成', () {
      expect(
        state.remaining(start.add(const Duration(minutes: 25))),
        Duration.zero,
      );
      expect(state.isFinished(start.add(const Duration(minutes: 25))), isTrue);
    });

    test('走过头了仍然是完成，remaining 为负', () {
      final Duration? left = state.remaining(
        start.add(const Duration(minutes: 30)),
      );
      expect(left, const Duration(minutes: -5));
      expect(state.isFinished(start.add(const Duration(minutes: 30))), isTrue);
    });

    test('暂停期间不会走满', () {
      final FocusTimerState paused = state.pause(
        start.add(const Duration(minutes: 5)),
      );
      expect(paused.isFinished(start.add(const Duration(hours: 3))), isFalse);
      expect(
        paused.remaining(start.add(const Duration(hours: 3))),
        const Duration(minutes: 20),
      );
    });

    test('progress 从 0 走到 1', () {
      expect(state.progress(start), 0);
      expect(
        state.progress(start.add(const Duration(minutes: 5))),
        closeTo(0.2, 1e-9),
      );
      expect(state.progress(start.add(const Duration(minutes: 25))), 1);
    });
  });

  group('正计时', () {
    final FocusTimerState state = FocusTimerState.started(
      at: start,
      mode: FocusTimerMode.countUp,
    );

    test('没有终点，所以永远不算完成', () {
      expect(state.remaining(start.add(const Duration(hours: 5))), isNull);
      expect(state.isFinished(start.add(const Duration(hours: 5))), isFalse);
    });

    test('没有分母，所以没有进度', () {
      expect(state.progress(start.add(const Duration(hours: 1))), isNull);
      expect(state.plannedSeconds, isNull);
    });

    test('已用时长照常算', () {
      expect(
        state.elapsed(start.add(const Duration(hours: 1))),
        const Duration(hours: 1),
      );
    });
  });

  group('构造约束', () {
    test('倒计时不给计划时长会被断言拦住', () {
      expect(
        () => FocusTimerState(
          startedAt: start,
          kind: FocusSessionKind.focus,
          mode: FocusTimerMode.countDown,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('默认是「专注 + 倒计时」', () {
      final FocusTimerState state = FocusTimerState.started(
        at: start,
        plan: const Duration(minutes: 25),
      );
      expect(state.kind, FocusSessionKind.focus);
      expect(state.mode, FocusTimerMode.countDown);
    });

    test('不给计划时长时用默认的 25 分钟，而不是崩掉', () {
      final FocusTimerState state = FocusTimerState.started(at: start);

      expect(state.plan, FocusTimerState.defaultPlan);
      expect(state.plannedSeconds, 1500);
    });

    test('正计时带上计划时长会被断言拦住', () {
      expect(
        () => FocusTimerState.started(
          at: start,
          mode: FocusTimerMode.countUp,
          plan: const Duration(minutes: 25),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith 能清掉 pausedAt', () {
      final FocusTimerState paused = FocusTimerState.started(
        at: start,
      ).pause(start);
      expect(paused.copyWith(clearPausedAt: true).pausedAt, isNull);
    });
  });
}
