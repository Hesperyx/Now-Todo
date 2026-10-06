import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enum_labels.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/notifications/focus_notification_sync.dart';
import 'package:now_todo/core/notifications/notification_ids.dart';
import 'package:now_todo/core/utils/time.dart';

import '../../helpers/recording_notification_service.dart';

/// 造一条会话。默认是「9:00 开始、倒计时 25 分钟、还在跑」。
TodoFocusSession session({
  required int startedAt,
  int? endedAt,
  int pausedMillis = 0,
  int? pausedAt,
  int? plannedSeconds = 1500,
  FocusSessionKind kind = FocusSessionKind.focus,
  FocusTimerMode timerMode = FocusTimerMode.countDown,
  int actualSeconds = 0,
  bool completed = false,
}) => TodoFocusSession(
  id: 's1',
  taskId: null,
  startedAt: startedAt,
  endedAt: endedAt,
  pausedMillis: pausedMillis,
  pausedAt: pausedAt,
  plannedSeconds: plannedSeconds,
  actualSeconds: actualSeconds,
  kind: kind,
  timerMode: timerMode,
  logicalDate: dayOnlyMillis(fromUtcMillis(startedAt)),
  completed: completed,
);

void main() {
  /// 用例里的「现在」。所有时刻都相对它来写，免得依赖真实时间。
  final DateTime anchor = DateTime(2030, 5, 1, 9);
  final int t0 = anchor.utcMillis;

  late StreamController<TodoFocusSession?> controller;
  late RecordingNotificationService notifications;
  late FocusNotificationSync sync;
  late DateTime current;

  setUp(() {
    current = anchor;
    controller = StreamController<TodoFocusSession?>.broadcast();
    notifications = RecordingNotificationService();
    sync = FocusNotificationSync(
      sessions: controller.stream,
      notifications: notifications,
      clock: () => current,
    );
    sync.start();
  });

  tearDown(() async {
    sync.dispose();
    await controller.close();
  });

  /// 推一条新状态，并等这一轮同步真正跑完。
  ///
  /// 用 `settled` 而不是 `refresh()` 那样的显式调用：同步是串行的异步队列，
  /// 直接 `await` 一个自己入队的操作会让同一份数据被处理两次。
  Future<void> deliver(TodoFocusSession? value) async {
    controller.add(value);
    await pumpEventQueue();
    await sync.settled;
  }

  group('倒计时', () {
    test('挂上带倒计时的常驻通知，并排一条到点提醒', () async {
      await deliver(session(startedAt: t0));

      final RecordedOngoing ongoing = notifications.ongoing.single;
      expect(ongoing.id, NotificationIds.focusOngoing);
      expect(ongoing.countdown, const Duration(minutes: 25));
      expect(ongoing.chronometerStart, isNull);
      expect(ongoing.title, '专注中');

      final RecordedSchedule alarm = notifications.scheduled.single;
      expect(alarm.id, NotificationIds.focusFinished);
      expect(alarm.channelId, NotificationChannels.focusAlerts);
      expect(alarm.exact, isTrue);
      // 终点是「开始时刻 + 计划时长」，不是「现在 + 计划时长」。
      expect(alarm.at, anchor.add(const Duration(minutes: 25)));
    });

    test('启动时库里已经有一条跑了 10 分钟的会话，剩余时间按现在算', () async {
      // 这就是「App 被划掉之后重开」：内存里什么都没有，只有库里那一条。
      current = anchor.add(const Duration(minutes: 10));
      await deliver(session(startedAt: t0));

      expect(
        notifications.ongoing.single.countdown,
        const Duration(minutes: 15),
      );
      expect(
        notifications.scheduled.single.at,
        current.add(const Duration(minutes: 15)),
      );
    });

    test('暂停时长不计入已用时间', () async {
      current = anchor.add(const Duration(minutes: 20));
      await deliver(session(startedAt: t0, pausedMillis: 600000));

      // 走了 20 分钟，其中 10 分钟是暂停的，所以还剩 15 分钟。
      expect(
        notifications.ongoing.single.countdown,
        const Duration(minutes: 15),
      );
    });

    test('已经走满：常驻通知不再挂计时器，也不排一条马上响的提醒去补刀', () async {
      current = anchor.add(const Duration(minutes: 30));
      await deliver(session(startedAt: t0));

      final RecordedOngoing ongoing = notifications.ongoing.single;
      expect(ongoing.countdown, isNull);
      expect(ongoing.chronometerStart, isNull);
      expect(notifications.scheduled, isEmpty);
    });
  });

  group('正计时', () {
    test('常驻通知带 chronometerStart，交给系统自己走，不排到点提醒', () async {
      await deliver(
        session(
          startedAt: t0,
          plannedSeconds: null,
          timerMode: FocusTimerMode.countUp,
        ),
      );

      final RecordedOngoing ongoing = notifications.ongoing.single;
      expect(ongoing.countdown, isNull);
      // 系统会把「现在 - chronometerStart」显示出来；累计暂停要往前挪。
      expect(ongoing.chronometerStart, anchor);
      expect(notifications.scheduled, isEmpty);
    });

    test('停过一段之后 chronometerStart 要往后挪', () async {
      await deliver(
        session(
          startedAt: t0,
          plannedSeconds: null,
          timerMode: FocusTimerMode.countUp,
          pausedMillis: 120000,
        ),
      );

      expect(
        notifications.ongoing.single.chronometerStart,
        anchor.add(const Duration(minutes: 2)),
      );
    });
  });

  group('暂停与恢复', () {
    test('暂停：撤掉到点提醒，常驻通知不再挂计时器', () async {
      await deliver(session(startedAt: t0));
      notifications.ongoing.clear();
      notifications.scheduled.clear();
      notifications.cancelled.clear();

      current = anchor.add(const Duration(minutes: 5));
      await deliver(session(startedAt: t0, pausedAt: current.utcMillis));

      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelled, contains(NotificationIds.focusFinished));
      final RecordedOngoing ongoing = notifications.ongoing.single;
      expect(ongoing.title, '已暂停');
      expect(ongoing.countdown, isNull);
      expect(ongoing.chronometerStart, isNull);
      expect(ongoing.body, contains('已用 05:00'));
    });

    test('恢复：终点从「现在」重新往后算，而不是接着旧的终点', () async {
      final int pausedAt = anchor.add(const Duration(minutes: 5)).utcMillis;
      current = anchor.add(const Duration(minutes: 20));
      await deliver(
        session(startedAt: t0, pausedAt: pausedAt, pausedMillis: 0),
      );
      notifications.scheduled.clear();

      // 恢复的那一刻累计暂停变成 15 分钟，已用 5 分钟，还剩 20 分钟。
      current = anchor.add(const Duration(minutes: 20));
      await deliver(session(startedAt: t0, pausedMillis: 900000));

      expect(
        notifications.scheduled.single.at,
        current.add(const Duration(minutes: 20)),
      );
    });
  });

  group('结束与清空', () {
    test('会话结束：撤常驻通知，撤到点提醒', () async {
      await deliver(session(startedAt: t0));
      notifications.cancelled.clear();

      await deliver(
        session(
          startedAt: t0,
          endedAt: current.utcMillis,
          actualSeconds: 1500,
          completed: true,
        ),
      );

      expect(notifications.stopOngoingCount, 1);
      expect(notifications.cancelled, contains(NotificationIds.focusFinished));
    });

    test('没有会话：同上，且不需要经过「跑着」这一态', () async {
      await deliver(null);

      expect(notifications.stopOngoingCount, 1);
      expect(notifications.cancelled, contains(NotificationIds.focusFinished));
      expect(notifications.ongoing, isEmpty);
      expect(notifications.scheduled, isEmpty);
    });
  });

  group('队列与生命周期', () {
    test('同一份状态推两遍，结果一样（不动系统里别的通知）', () async {
      final TodoFocusSession value = session(startedAt: t0);
      await deliver(value);
      await deliver(value);

      expect(notifications.ongoing, hasLength(2));
      expect(
        notifications.ongoing.first.countdown,
        const Duration(minutes: 25),
      );
      expect(notifications.ongoing.last.countdown, const Duration(minutes: 25));
      expect(notifications.scheduled, hasLength(2));
      expect(notifications.scheduled.first.at, notifications.scheduled.last.at);
    });

    test('dispose 之后状态再变也不动通知', () async {
      sync.dispose();
      controller.add(session(startedAt: t0));
      await pumpEventQueue();

      expect(notifications.ongoing, isEmpty);
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelled, isEmpty);
    });

    test('start 调两次只订阅一次', () async {
      sync.start();
      await deliver(session(startedAt: t0));

      expect(notifications.ongoing, hasLength(1));
    });
  });

  group('常驻通知文案', () {
    test('三种会话类型各自的标题', () {
      for (final FocusSessionKind kind in FocusSessionKind.values) {
        final ({String title, String body}) content = buildOngoingContent(
          session: session(startedAt: t0, kind: kind),
          now: anchor,
        );
        expect(content.title, '${kind.label}中');
        expect(content.body, isNotEmpty);
      }
    });

    test('暂停时说明已用多久', () {
      final ({String title, String body}) content = buildOngoingContent(
        session: session(
          startedAt: t0,
          pausedAt: anchor
              .add(const Duration(minutes: 12, seconds: 34))
              .utcMillis,
        ),
        now: anchor.add(const Duration(minutes: 12, seconds: 34)),
      );

      expect(content.title, '已暂停');
      expect(content.body, '专注已用 12:34');
    });
  });
}
