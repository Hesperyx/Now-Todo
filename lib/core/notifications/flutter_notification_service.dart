import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_ids.dart';
import 'notification_service.dart';

/// [NotificationService] 的真实实现，底层是 `flutter_local_notifications`。
///
/// **只在 Android 上做事**：桌面构建里插件没有平台通道，任何调用都会抛
/// `MissingPluginException`。与其到处 try/catch，不如在一处判断平台，
/// 非 Android 直接按 no-op 返回。
class FlutterNotificationService implements NotificationService {
  FlutterNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android => _isAndroid
      ? _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  @override
  Future<void> initialize({void Function(String taskId)? onOpenTask}) async {
    if (!_isAndroid) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        onOpenTask?.call(payload);
      },
    );
    await _createChannels();
  }

  /// 渠道必须在应用里显式建：`AndroidNotificationDetails` 里传的名字只在
  /// **首次**创建该渠道时生效，之后改代码不会更新系统里的渠道，很容易
  /// 出现「改了重要性却没生效」的假象。
  Future<void> _createChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.reminders,
        '任务提醒',
        description: '任务到点时的提醒通知',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.focusAlerts,
        '专注结束提醒',
        description: '专注计时结束时提醒一次',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.focusOngoing,
        '专注进行中',
        description: '专注计时期间常驻，显示已用时间',
        // 常驻通知是为了「一眼能看到还剩多久」，不该每次都响。
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return false;
    final bool? granted = await android.requestNotificationsPermission();
    if (granted != null) return granted;
    return areNotificationsEnabled();
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return false;
    return await android.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> canScheduleExact() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? true;
    } on Object catch (error) {
      // Android 12 以下没有这个 API，插件版本差异也可能抛出来。
      // 问不到就当能排——排不上的话系统会退化成非精确，代价只是晚几分钟。
      debugPrint('查询精确闹钟权限失败，按可排处理：$error');
      return true;
    }
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return false;
    final bool? granted = await android.requestExactAlarmsPermission();
    if (granted == true) return true;
    return canScheduleExact();
  }

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
    if (!_isAndroid) return;
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      // 必须转成 TZDateTime：插件内部按 tz.local 解释这个时刻，
      // 直接传 DateTime 在跨时区或夏令时切换时会偏。
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName(channelId),
          channelDescription: _channelDescription(channelId),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          additionalFlags: insistent ? _insistentFlag : null,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// `Notification.FLAG_INSISTENT`（值为 4）。
  ///
  /// 插件只是把它按位或到 `Notification.flags` 上（见插件 Android 源码
  /// `FlutterLocalNotificationsPlugin.java:447-452`），所以这里给的必须是
  /// 系统常量的裸值。它会一直循环播放提示音，直到用户处理掉这条通知。
  ///
  /// **勿扰与静音会压制它**，这是系统行为不是缺陷；设置页的文案要把这点
  /// 说清楚，不能让用户以为「开了强提醒就一定叫得醒」。
  static final Int32List _insistentFlag = Int32List.fromList(const <int>[4]);

  static String _channelName(String channelId) => switch (channelId) {
    NotificationChannels.reminders => '任务提醒',
    NotificationChannels.focusAlerts => '专注结束提醒',
    NotificationChannels.focusOngoing => '专注进行中',
    _ => '通知',
  };

  static String _channelDescription(String channelId) => switch (channelId) {
    NotificationChannels.reminders => '任务到点时的提醒通知',
    NotificationChannels.focusAlerts => '专注计时结束时提醒一次',
    NotificationChannels.focusOngoing => '专注计时期间常驻，显示已用时间',
    _ => '',
  };

  @override
  Future<void> cancel(int notificationId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<void> cancelReminderNotifications() async {
    if (!_isAndroid) return;
    // 只能问系统「现在挂着哪些」，而不是查自己记的账：应用被强杀过之后，
    // 进程里的记录是空的，但系统里的闹钟还在。
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    for (final PendingNotificationRequest request in pending) {
      if (NotificationIds.isReminder(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
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
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return;

    // 两种计时方向共用一条通知：给了 [countdown] 就渲染「还剩多久」，
    // 否则用 [chronometerStart] 渲染「已经过了多久」。
    final bool countingDown = countdown != null;
    final DateTime? reference = countingDown
        ? DateTime.now().add(countdown)
        : chronometerStart;

    await android.startForegroundService(
      id: notificationId,
      title: title,
      body: body,
      payload: payload,
      foregroundServiceTypes: const <AndroidServiceForegroundType>{
        // Android 14+ 必须声明类型。专注计时不属于导航/通话/媒体任何一类，
        // 只能用 specialUse，并在 AndroidManifest 里用 property 说明用途
        // ——系统会拿那句说明来审核。
        AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
      },
      notificationDetails: AndroidNotificationDetails(
        NotificationChannels.focusOngoing,
        _channelName(NotificationChannels.focusOngoing),
        channelDescription: _channelDescription(
          NotificationChannels.focusOngoing,
        ),
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        // 计时过程中反复提醒只会让用户想把这条通知划掉，而划掉它
        // 就等于关掉计时器。所以它只更新数字，不出声。
        onlyAlertOnce: true,
        silent: true,
        // 锁屏上要看得见进度。这条通知的内容只有一个计时数字和「已暂停」，
        // 不含任务标题，所以没有需要遮挡的信息；反过来用户锁屏时想看的
        // 恰恰就是还剩多久。系统默认（private）在「隐藏敏感内容」开启时
        // 会把正文抹成一行占位文字，进度就没了。
        visibility: NotificationVisibility.public,
        showWhen: reference != null,
        when: reference?.millisecondsSinceEpoch,
        usesChronometer: reference != null,
        chronometerCountDown: countingDown,
        category: AndroidNotificationCategory.stopwatch,
      ),
    );
  }

  @override
  Future<void> stopOngoing() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return;
    await android.stopForegroundService();
  }
}
