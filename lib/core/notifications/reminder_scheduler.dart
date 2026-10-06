import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/reminder_repository.dart';
import 'notification_ids.dart';
import 'notification_service.dart';
import 'reminder_plan.dart';

/// 把「库里的提醒」翻译成「系统里排好的通知」。
///
/// 两条输入流：
/// - **提醒数据**（含任务标题与完成状态）——任何一条变了都要重算计划；
/// - **排程偏好**（总开关 + 强提醒）——总开关关掉时要把已排的全部撤掉，
///   而不是留着让它响；强提醒改变后要按新方式重排。
///
/// 两个偏好打包成一个 [ReminderSettings] 而不是两条独立流：它们总是一起
/// 变化，分成两条会让调度器在中间态多跑一轮没有意义的全量重排。
///
/// 每次重算都是**全量覆盖**：先把计划判定不该响的撤掉，再把该响的排上。
/// 之所以不做增量 diff，是因为应用可能被系统强杀过，进程里记的「我排过
/// 什么」根本不可信；而「取消一个没排过的通知」是幂等的空操作，代价是零。
class ReminderScheduler {
  ReminderScheduler({
    required ReminderRepository repository,
    required NotificationService notifications,
    required ReminderSettings initial,
    required Stream<ReminderSettings> settings,
    DateTime Function()? clock,
  }) : _repository = repository,
       _notifications = notifications,
       _settings = initial,
       _settingsStream = settings,
       _clock = clock ?? DateTime.now;

  final ReminderRepository _repository;
  final NotificationService _notifications;
  final Stream<ReminderSettings> _settingsStream;
  final DateTime Function() _clock;

  ReminderSettings _settings;
  bool _started = false;
  bool _exactAllowed = true;
  List<ReminderSource>? _latestSources;

  StreamSubscription<List<ReminderSource>>? _sourceSubscription;
  StreamSubscription<ReminderSettings>? _settingsSubscription;

  /// 所有重算排成一条队列。
  ///
  /// 不加这个的话，提醒列表和总开关可能几乎同时变化，两次重算就会交错
  /// 执行 cancel / schedule——最后排上什么完全看时序。
  Future<void> _queue = Future<void>.value();

  /// 最近一次排程实际排上的条数。设置页用它显示「已排程 N 条提醒」。
  int get scheduledCount => _scheduledCount;
  int _scheduledCount = 0;

  /// 开始监听。要求 [NotificationService.initialize] 已经跑过。
  void start() {
    if (_started) return;
    _started = true;
    _settingsSubscription = _settingsStream.listen(
      (ReminderSettings settings) {
        _settings = settings;
        _enqueue();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('通知偏好监听失败：$error');
      },
    );
    _sourceSubscription = _repository.watchSources().listen(
      (List<ReminderSource> sources) {
        _latestSources = sources;
        _enqueue();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('提醒监听失败：$error');
      },
    );
  }

  /// 手动触发一次重算。
  ///
  /// 用在「刚拿到通知权限」「用户从系统设置里改了精确闹钟开关」这类
  /// 数据没变但系统状态变了的场合。
  Future<void> refresh() {
    _enqueue();
    return _queue;
  }

  /// 当前排队中的重算全部跑完之后才完成。
  ///
  /// 重算是串行队列上的异步操作，`start()` 返回时一条都没排完。需要一个
  /// 「已经收敛」的同步点时用它——测试要断言的就是这个时刻的状态。
  Future<void> get settled => _queue;

  Future<void> dispose() async {
    _started = false;
    await _settingsSubscription?.cancel();
    await _sourceSubscription?.cancel();
    _settingsSubscription = null;
    _sourceSubscription = null;
    // 队列里可能还有没跑完的一次重算，等它结束再返回，
    // 否则调用方以为已经收工了，实际还在往系统里排通知。
    await _queue;
  }

  void _enqueue() {
    _queue = _queue.then((_) => _apply()).catchError((
      Object error,
      StackTrace stack,
    ) {
      // 单次重算失败不能让订阅断掉：提醒排不上是可惜，
      // 但从此再也不排就是坏了。
      debugPrint('提醒排程失败：$error\n$stack');
    });
  }

  Future<void> _apply() async {
    if (!_settings.enabled) {
      await _notifications.cancelReminderNotifications();
      _scheduledCount = 0;
      return;
    }
    final List<ReminderSource>? sources = _latestSources;
    if (sources == null) return; // 数据还没来，等它

    // 每次都重新问，不缓存：用户可以在系统设置里随时收回这个权限。
    _exactAllowed = await _notifications.canScheduleExact();

    final ReminderPlan plan = buildReminderPlan(
      reminders: sources,
      now: _clock(),
    );

    for (final String reminderId in plan.cancel) {
      await _guard(
        () => _notifications.cancel(NotificationIds.forReminder(reminderId)),
      );
    }

    int scheduled = 0;
    for (final ReminderSlot slot in plan.schedule) {
      final ({String title, String body}) content = buildReminderContent(
        taskTitle: slot.taskTitle,
        repeat: slot.repeatType,
      );
      final bool ok = await _guard(
        () => _notifications.schedule(
          notificationId: NotificationIds.forReminder(slot.reminderId),
          title: content.title,
          body: content.body,
          at: slot.at,
          channelId: NotificationChannels.reminders,
          payload: slot.taskId,
          exact: _exactAllowed,
          insistent: _settings.strong,
        ),
      );
      if (ok) scheduled++;
    }
    _scheduledCount = scheduled;
  }

  /// 单条通知失败（比如系统不给排了）不该让整轮排程中断。
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on Object catch (error) {
      debugPrint('通知操作失败，跳过这一条：$error');
      return false;
    }
  }
}

/// 会影响排程结果的那几个偏好。
///
/// 单独定义而不是直接传 `AppPreferences`：调度器只该认识它真正用得上的
/// 两个字段，否则每次往设置表里加一列，调度器都要跟着重新编译一次。
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.strong});

  /// 总开关。false 时撤掉全部提醒通知。
  final bool enabled;

  /// 强提醒。true 时到点后持续响铃（会被系统勿扰 / 静音压制）。
  final bool strong;

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.strong == strong;

  @override
  int get hashCode => Object.hash(enabled, strong);

  @override
  String toString() => 'ReminderSettings(enabled: $enabled, strong: $strong)';
}
