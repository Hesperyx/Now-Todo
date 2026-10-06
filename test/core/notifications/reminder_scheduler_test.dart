import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/notifications/notification_ids.dart';
import 'package:now_todo/core/notifications/notification_service.dart';
import 'package:now_todo/core/notifications/reminder_plan.dart';
import 'package:now_todo/core/notifications/reminder_scheduler.dart';
import 'package:now_todo/data/repositories/reminder_repository.dart';

class _MockReminderRepository extends Mock implements ReminderRepository {}

/// 一次 `schedule` 调用的完整记录。
class _ScheduledCall {
  _ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
    required this.exact,
    required this.insistent,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String payload;
  final bool exact;
  final bool insistent;

  @override
  String toString() =>
      'schedule(id: $id, payload: $payload, at: $at, '
      'exact: $exact, insistent: $insistent)';
}

/// 把调度器往系统里的每一次写操作都记下来。
///
/// 这是 `NotificationService` 抽成接口的全部意义：真的去调
/// `flutter_local_notifications` 的话，测试里既没有平台通道，也没法断言
/// 「到底排了哪几条」。
class _RecordingNotificationService implements NotificationService {
  final List<_ScheduledCall> scheduled = <_ScheduledCall>[];
  final List<int> cancelled = <int>[];
  int cancelAllCount = 0;
  int initializeCount = 0;

  /// 置 false 模拟「用户收回了精确闹钟权限」。
  bool exactAllowed = true;

  /// 这些 id 的排程会抛，用来验证单条失败不影响整轮。
  final Set<int> failing = <int>{};

  @override
  Future<void> initialize({void Function(String taskId)? onOpenTask}) async {
    initializeCount++;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String channelId,
    String? payload,
    bool exact = true,
    bool insistent = false,
  }) async {
    if (failing.contains(notificationId)) {
      throw StateError('系统不给排 $notificationId');
    }
    scheduled.add(
      _ScheduledCall(
        id: notificationId,
        title: title,
        body: body,
        at: at,
        payload: payload ?? '',
        exact: exact,
        insistent: insistent,
      ),
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }

  @override
  Future<void> cancelReminderNotifications() async {
    cancelAllCount++;
  }

  @override
  Future<void> showOngoing({
    required int notificationId,
    required String title,
    required String body,
    DateTime? chronometerStart,
    Duration? countdown,
    String? payload,
  }) async {}

  @override
  Future<void> stopOngoing() async {}
}

void main() {
  /// 用例里的「现在」。所有提醒时刻都相对它来写，免得依赖真实时间。
  final DateTime now = DateTime(2030, 5, 1, 8);

  late _MockReminderRepository repository;
  late _RecordingNotificationService notifications;
  late StreamController<List<ReminderSource>> sources;
  late StreamController<ReminderSettings> settings;
  late ReminderScheduler scheduler;

  ReminderSource source({
    String id = 'r1',
    String taskId = 't1',
    String taskTitle = '交周报',
    bool taskCompleted = false,
    required DateTime remindAt,
    ReminderRepeatType repeatType = ReminderRepeatType.once,
    bool enabled = true,
  }) => ReminderSource(
    id: id,
    taskId: taskId,
    taskTitle: taskTitle,
    taskCompleted: taskCompleted,
    remindAt: remindAt.millisecondsSinceEpoch,
    repeatType: repeatType,
    enabled: enabled,
  );

  /// 推一批数据，并等到这一轮重算跑完。
  ///
  /// 不能只 `add` 完就断言：stream 是异步送达的，`_apply` 又在一条串行
  /// 队列上。先 `pumpEventQueue()` 让监听器把重算入队，再 `settled` 等它
  /// 真正跑完——这样每次 `deliver` 恰好对应一轮排程，断言才数得清。
  Future<void> deliver(List<ReminderSource> list) async {
    sources.add(list);
    await pumpEventQueue();
    await scheduler.settled;
  }

  Future<void> applySettings(ReminderSettings next) async {
    settings.add(next);
    await pumpEventQueue();
    await scheduler.settled;
  }

  setUp(() {
    repository = _MockReminderRepository();
    notifications = _RecordingNotificationService();
    sources = StreamController<List<ReminderSource>>.broadcast();
    settings = StreamController<ReminderSettings>.broadcast();
    when(() => repository.watchSources()).thenAnswer((_) => sources.stream);
    scheduler = ReminderScheduler(
      repository: repository,
      notifications: notifications,
      initial: const ReminderSettings(enabled: true, strong: false),
      settings: settings.stream,
      clock: () => now,
    );
  });

  tearDown(() async {
    await scheduler.dispose();
    await sources.close();
    await settings.close();
  });

  test('未完成任务的启用提醒会被排上，并带上任务 id 与标题', () async {
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);

    expect(notifications.scheduled, hasLength(1));
    final _ScheduledCall call = notifications.scheduled.single;
    expect(call.id, NotificationIds.forReminder('r1'));
    expect(call.at, DateTime(2030, 5, 1, 9));
    // payload 决定「点通知跳哪条任务」，错了就会跳到别的任务上。
    expect(call.payload, 't1');
    expect(call.title, '交周报');
    expect(call.body, '提醒时间到了');
    expect(scheduler.scheduledCount, 1);
  });

  test('任务已完成时不排，并撤销可能已排的那条', () async {
    scheduler.start();
    await deliver(<ReminderSource>[
      source(remindAt: DateTime(2030, 5, 1, 9), taskCompleted: true),
    ]);

    expect(notifications.scheduled, isEmpty);
    expect(notifications.cancelled, <int>[NotificationIds.forReminder('r1')]);
    expect(scheduler.scheduledCount, 0);
  });

  test('单条提醒被关掉时不排，但记录不删（靠撤销实现）', () async {
    scheduler.start();
    await deliver(<ReminderSource>[
      source(remindAt: DateTime(2030, 5, 1, 9), enabled: false),
    ]);

    expect(notifications.scheduled, isEmpty);
    expect(
      notifications.cancelled,
      contains(NotificationIds.forReminder('r1')),
    );
  });

  test('一次性提醒已经过点时撤销，不排', () async {
    scheduler.start();
    await deliver(<ReminderSource>[
      // 恰好等于「现在」也算过点：闹钟已经在响了，再排一次是重复通知。
      source(remindAt: now),
    ]);

    expect(notifications.scheduled, isEmpty);
    expect(
      notifications.cancelled,
      contains(NotificationIds.forReminder('r1')),
    );
  });

  test('重复提醒排的是下一次，不是原始时间', () async {
    scheduler.start();
    await deliver(<ReminderSource>[
      source(
        remindAt: DateTime(2030, 4, 1, 9),
        repeatType: ReminderRepeatType.daily,
      ),
    ]);

    expect(notifications.scheduled.single.at, DateTime(2030, 5, 1, 9));
    // 通知正文要带重复说明，否则用户不知道这条会不会再来一次。
    expect(notifications.scheduled.single.body, '提醒时间到了（每天）');
  });

  test('强提醒打开时，排程带上 insistent', () async {
    scheduler.start();
    await applySettings(const ReminderSettings(enabled: true, strong: true));
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);

    expect(notifications.scheduled.single.insistent, isTrue);
  });

  test('强提醒默认不开：默认排的是普通提醒', () async {
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);

    expect(notifications.scheduled.single.insistent, isFalse);
  });

  test('没有精确闹钟权限时退化为非精确排程，而不是不排', () async {
    notifications.exactAllowed = false;
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);

    expect(notifications.scheduled, hasLength(1));
    expect(notifications.scheduled.single.exact, isFalse);
  });

  test('关掉总开关会撤销全部提醒通知，计数归零', () async {
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);
    expect(scheduler.scheduledCount, 1);

    await applySettings(const ReminderSettings(enabled: false, strong: false));

    expect(notifications.cancelAllCount, greaterThan(0));
    expect(scheduler.scheduledCount, 0);
    // 关开关期间库里还有数据，但一条都不该排上去。
    expect(notifications.scheduled, hasLength(1));
  });

  test('重新打开总开关后按当前数据排上', () async {
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);
    await applySettings(const ReminderSettings(enabled: false, strong: false));

    await applySettings(const ReminderSettings(enabled: true, strong: false));

    expect(notifications.scheduled, hasLength(2));
    expect(scheduler.scheduledCount, 1);
  });

  test('单条排程失败不影响其余条目', () async {
    notifications.failing.add(NotificationIds.forReminder('r1'));
    scheduler.start();
    await deliver(<ReminderSource>[
      source(id: 'r1', remindAt: DateTime(2030, 5, 1, 9)),
      source(id: 'r2', remindAt: DateTime(2030, 5, 1, 10)),
    ]);

    expect(notifications.scheduled, hasLength(1));
    expect(
      notifications.scheduled.single.id,
      NotificationIds.forReminder('r2'),
    );
    // 计数只算真的排上的，否则设置页会显示一个骗人的数字。
    expect(scheduler.scheduledCount, 1);
  });

  test('先撤后排', () async {
    scheduler.start();
    await deliver(<ReminderSource>[
      source(id: 'r1', remindAt: DateTime(2030, 5, 1, 9), enabled: false),
      source(id: 'r2', remindAt: DateTime(2030, 5, 1, 10)),
    ]);

    expect(
      notifications.cancelled,
      contains(NotificationIds.forReminder('r1')),
    );
    expect(
      notifications.scheduled.single.id,
      NotificationIds.forReminder('r2'),
    );
  });

  test('数据还没到时不动作，不误撤销', () async {
    scheduler.start();
    // 只启动、不推数据，`_latestSources` 还是 null。
    await scheduler.refresh();

    expect(notifications.cancelAllCount, 0);
    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduled, isEmpty);
    expect(scheduler.scheduledCount, 0);
  });

  test('dispose 之后数据再变也不排', () async {
    scheduler.start();
    await deliver(<ReminderSource>[source(remindAt: DateTime(2030, 5, 1, 9))]);
    final int before = notifications.scheduled.length;

    await scheduler.dispose();
    sources.add(<ReminderSource>[]);
    await pumpEventQueue();
    await pumpEventQueue();

    expect(notifications.scheduled, hasLength(before));
  });

  test('同一批数据跑两遍，结果一样（幂等）', () async {
    scheduler.start();
    final List<ReminderSource> list = <ReminderSource>[
      source(remindAt: DateTime(2030, 5, 1, 9)),
    ];
    await deliver(list);
    await deliver(list);

    // 全量覆盖的意义就在这里：系统里最终是什么状态只取决于这批数据，
    // 不取决于之前排过什么、应用有没有被强杀过。
    expect(notifications.scheduled, hasLength(2));
    expect(scheduler.scheduledCount, 1);
  });
}
