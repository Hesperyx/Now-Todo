import '../models/enums.dart';

/// 通知平台能力的最小接口。
///
/// 存在的理由是**可测**：`flutter_local_notifications` 在测试环境里没有
/// 平台通道，任何调用都是 throw 或者静默 no-op，所以业务逻辑不能直接
/// 依赖它。`ReminderScheduler` 只认识这个接口，测试里换成记录用的假实现
/// 就能把「排了哪些、撤了哪些」全部断言出来。
///
/// 真实实现见 `flutter_notification_service.dart`，它只在 Android 上做事。
abstract interface class NotificationService {
  /// 建通知渠道、绑定点击回调。应用启动时调一次。
  ///
  /// [onOpenTask] 在用户点通知时被调用，参数是被点那条提醒所属的任务 id。
  /// 排程时把任务 id 当作 payload 带过去，点击才能落到正确的那条任务上。
  Future<void> initialize({void Function(String taskId)? onOpenTask});

  /// 申请通知权限（Android 13+ 需要运行时授权），返回申请后是否已授权。
  Future<bool> requestPermission();

  /// 系统当前是否允许这个应用发通知。
  Future<bool> areNotificationsEnabled();

  /// 现在能不能排**精确**闹钟。
  ///
  /// Android 12+ 起，`SCHEDULE_EXACT_ALARM` 可以被用户随时收回，
  /// 所以这个值要在每次排程前重新问一遍，不能启动时读一次缓存到底。
  Future<bool> canScheduleExact();

  /// 申请精确闹钟权限，返回申请后是否可用。
  Future<bool> requestExactAlarmPermission();

  /// 排一条定时通知。同一个 [notificationId] 会覆盖上一条。
  ///
  /// [exact] 为 false 时用非精确闹钟——晚几分钟，但不需要特殊权限。
  /// [insistent] 为 true 时到点后持续响铃，直到用户处理掉这条通知。
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String channelId,
    String? payload,
    bool exact = true,
    bool insistent = false,
  });

  /// 撤销一条已排的通知。撤销一条没排过的通知是空操作。
  Future<void> cancel(int notificationId);

  /// 撤销**全部提示类**通知，但保留专注计时用的常驻通知
  /// （它是前台服务的门面，撤掉会让用户以为专注已经结束）。
  Future<void> cancelReminderNotifications();

  /// 显示或更新常驻通知（Android 前台服务）。
  ///
  /// 和提醒是两条独立通道：`cancelReminderNotifications()` 不会碰它。
  ///
  /// [chronometerStart] 给「已用多久」，[countdown] 给「还剩多久」，两者
  /// 都交给系统渲染。**不能让应用每秒改一次通知文本**：进程被系统压制时
  /// 数字就停住了，而用户看到的会是一个安静地卡住的计时器。
  Future<void> showOngoing({
    required int notificationId,
    required String title,
    required String body,
    DateTime? chronometerStart,
    Duration? countdown,
    String? payload,
  });

  /// 撤掉常驻通知并停掉前台服务。没启动过时是空操作。
  Future<void> stopOngoing();
}

/// 什么都不做的实现。
///
/// 用在两处：Windows 桌面预览（没有通知平台通道），以及任何
/// 不应该真的弹通知的场合。
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> initialize({void Function(String taskId)? onOpenTask}) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<bool> canScheduleExact() async => false;

  @override
  Future<bool> requestExactAlarmPermission() async => false;

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
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> cancelReminderNotifications() async {}

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

/// 系统当前的通知权限现状。
///
/// 两个值应用都改不了，只能读出来并把用户引到系统设置。之所以要显示它们，
/// 是因为权限被拒时提醒是**静默不响**的——用户看到的界面若写着「提醒已开启」，
/// 他就会一直等一个永远不会来的通知，然后以为这个功能本来就坏。
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  /// 系统是否允许本应用发通知。
  final bool notificationsAllowed;

  /// 是否允许排**精确**闹钟。
  ///
  /// 为 false 时提醒仍会响，只是可能晚几分钟——所以这是「降级」不是「失效」，
  /// 文案上要分开说。
  final bool exactAlarmsAllowed;

  /// 两项都齐才算「完全体」。
  bool get isFullyAllowed => notificationsAllowed && exactAlarmsAllowed;
}

/// 提醒通知的标题与正文。
///
/// 抽成纯函数有两个好处：文案可以单测；「通知长什么样」这件事不会散落
/// 进调度器，改文案不用碰逻辑。
({String title, String body}) buildReminderContent({
  required String taskTitle,
  required ReminderRepeatType repeat,
}) {
  final String suffix = switch (repeat) {
    ReminderRepeatType.once => '',
    ReminderRepeatType.daily => '（每天）',
    ReminderRepeatType.weekly => '（每周）',
    ReminderRepeatType.monthly => '（每月）',
  };
  final String title = taskTitle.trim().isEmpty ? '未命名任务' : taskTitle;
  return (title: title, body: '提醒时间到了$suffix');
}
