import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import '../models/enum_labels.dart';
import '../utils/time.dart';
import 'notification_ids.dart';
import 'notification_service.dart';

/// 常驻通知跟着「有没有在跑的会话」走。
///
/// 这里**只负责把状态翻译成通知**，不持有计时状态。会话本身在库里，
/// 时长由时间戳算出，所以进程被杀掉再起来时这一层不需要恢复任何东西
/// —— 重新订阅一次 `watchRunning()` 就能得到正确答案。
///
/// 重排走串行队列，理由和 `ReminderScheduler` 一样：两个状态变更挨得太近时
/// 会交错，后一轮的 `cancel` 可能把前一轮刚排上的东西撤掉。
class FocusNotificationSync {
  FocusNotificationSync({
    required Stream<TodoFocusSession?> sessions,
    required NotificationService notifications,
    DateTime Function()? clock,
  }) : _sessions = sessions,
       _notifications = notifications,
       _clock = clock ?? DateTime.now;

  final Stream<TodoFocusSession?> _sessions;
  final NotificationService _notifications;
  final DateTime Function() _clock;

  StreamSubscription<TodoFocusSession?>? _subscription;
  Future<void> _queue = Future<void>.value();

  /// 订阅会话流。可以重复调用，只生效一次。
  void start() {
    _subscription ??= _sessions.listen(
      _enqueue,
      onError: (Object error) => debugPrint('专注通知同步失败：$error'),
    );
  }

  /// 当前排队中的同步全部跑完之后才完成。
  ///
  /// 同步是串行队列上的异步操作，`start()` 返回时一条都没跑完。测试要断言
  /// 「已经收敛」时用它，而不是去猜要 `pump` 几次。
  Future<void> get settled => _queue;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _enqueue(TodoFocusSession? session) {
    _queue = _queue
        .then((_) => _apply(session))
        .catchError((Object error) => debugPrint('专注通知同步失败：$error'));
  }

  Future<void> _apply(TodoFocusSession? session) async {
    if (session == null || !session.isRunning) {
      await _notifications.stopOngoing();
      await _notifications.cancel(NotificationIds.focusFinished);
      return;
    }

    final DateTime now = _clock();
    final ({String title, String body}) content = buildOngoingContent(
      session: session,
      now: now,
    );

    // 到点提醒先撤再按当前状态重排。暂停会让终点往后挪、恢复又挪回来，
    // 留一条旧的在系统里就会出现「已经暂停了却还是响了」。
    await _notifications.cancel(NotificationIds.focusFinished);

    if (session.isPaused) {
      // 暂停中不挂计时器：挂在那里会继续往上走，而时间其实是停住的。
      await _notifications.showOngoing(
        notificationId: NotificationIds.focusOngoing,
        title: content.title,
        body: content.body,
      );
      return;
    }

    final Duration? remaining = session.toTimerState().remaining(now);
    if (remaining == null) {
      // 正计时没有终点，只说明已经过了多久。走 `chronometerStart` 交给系统
      // 渲染：应用每秒改一次通知文本的话，进程一被压制数字就停在原地。
      await _notifications.showOngoing(
        notificationId: NotificationIds.focusOngoing,
        title: content.title,
        body: content.body,
        chronometerStart: fromUtcMillis(
          session.startedAt + session.pausedMillis,
        ),
      );
      return;
    }

    if (remaining <= Duration.zero) {
      // 已经走满了，收尾由界面（或下一次启动）负责。这里不排一条「马上响」
      // 的提醒去补刀——用户可能正看着这个页面。
      await _notifications.showOngoing(
        notificationId: NotificationIds.focusOngoing,
        title: content.title,
        body: content.body,
      );
      return;
    }

    await _notifications.showOngoing(
      notificationId: NotificationIds.focusOngoing,
      title: content.title,
      body: content.body,
      countdown: remaining,
    );
    // 兜底提醒。App 在前台时界面会先一步收尾并撤掉它；App 在后台或被划掉时
    // 就靠这一条把「时间到了」送到用户面前。
    await _notifications.schedule(
      notificationId: NotificationIds.focusFinished,
      title: '${session.kind.label}结束',
      body: '时间到了。',
      at: now.add(remaining),
      channelId: NotificationChannels.focusAlerts,
      payload: 'focus',
      // 番茄钟晚三分钟才响就失去意义了，这里必须精确。
      exact: true,
    );
  }
}

/// 常驻通知的文案。
///
/// 刻意不显示任务标题：那需要把 `tasks` 表 join 进来，而通知文案不值得为它
/// 多一次查询、多一条数据依赖。
({String title, String body}) buildOngoingContent({
  required TodoFocusSession session,
  required DateTime now,
}) {
  if (session.isPaused) {
    final Duration used = session.toTimerState().elapsed(now);
    return (
      title: '已暂停',
      body: '${session.kind.label}已用 ${formatDuration(used)}',
    );
  }
  return (title: '${session.kind.label}中', body: '点开可以暂停或结束');
}
