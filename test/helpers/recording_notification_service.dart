import 'package:now_todo/core/notifications/notification_service.dart';

/// 一次 `schedule` 调用的完整记录。
class RecordedSchedule {
  RecordedSchedule({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.channelId,
    required this.payload,
    required this.exact,
    required this.insistent,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String channelId;
  final String payload;
  final bool exact;
  final bool insistent;

  @override
  String toString() =>
      'schedule(id: $id, payload: $payload, at: $at, '
      'exact: $exact, insistent: $insistent)';
}

/// 一次 `showOngoing` 调用的记录。
///
/// `chronometerStart` 与 `countdown` 至多有一个非空：前者是「已用多久」，
/// 后者是「还剩多久」，两个都交给系统自己渲染。
class RecordedOngoing {
  const RecordedOngoing({
    required this.id,
    required this.title,
    required this.body,
    this.chronometerStart,
    this.countdown,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? chronometerStart;
  final Duration? countdown;

  @override
  String toString() =>
      'ongoing(id: $id, title: $title, chronometerStart: $chronometerStart, '
      'countdown: $countdown)';
}

/// 把服务往系统里的每一次写操作都记下来。
///
/// 这是 `NotificationService` 抽成接口的全部意义：真的去调
/// `flutter_local_notifications` 的话，测试里既没有平台通道，也没法断言
/// 「到底排了哪几条」「常驻通知上写的是什么」。
class RecordingNotificationService implements NotificationService {
  final List<RecordedSchedule> scheduled = <RecordedSchedule>[];
  final List<int> cancelled = <int>[];
  final List<RecordedOngoing> ongoing = <RecordedOngoing>[];
  int cancelAllCount = 0;
  int initializeCount = 0;
  int stopOngoingCount = 0;

  /// 置 false 模拟「用户在系统里收回了通知权限」。
  bool notificationsAllowed = true;

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
  Future<bool> areNotificationsEnabled() async => notificationsAllowed;

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
      RecordedSchedule(
        id: notificationId,
        title: title,
        body: body,
        at: at,
        channelId: channelId,
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
  }) async {
    ongoing.add(
      RecordedOngoing(
        id: notificationId,
        title: title,
        body: body,
        chronometerStart: chronometerStart,
        countdown: countdown,
      ),
    );
  }

  @override
  Future<void> stopOngoing() async {
    stopOngoingCount++;
  }
}
