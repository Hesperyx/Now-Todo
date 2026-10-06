import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/constants/app_constants.dart';
import 'core/models/entities.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/timezone_bootstrap.dart';
import 'data/database/app_database.dart';
import 'data/repositories/settings_repository.dart';

/// 入口。
///
/// 顺序很重要，别随手调：
/// 1. `ensureInitialized()` —— 建表 / 补内置清单与设置行（幂等，见 [AppDatabase.ensureInitialized]）；
/// 2. 读一次偏好快照 —— 首屏的默认视图与主题要用它；
/// 3. 初始化时区 —— 必须早于任何 `zonedSchedule`；
/// 4. 拉起提醒调度器 —— 它一被创建就开始工作；
/// 5. 拉起时区监听 —— 设备时区变更后重排提醒；
/// 6. 拉起专注通知同步 —— 上次没结束的那段会话要把常驻通知接回去；
/// 7. 拉起小组件同步 —— 桌面上那块卡片要在应用一打开就是新数字；
/// 8. 才 `runApp`。
///
/// 把第 2 步放在 `runApp` 之前，是为了让首帧就知道该用「今天」还是「全部」，
/// 不会先渲染一屏「全部」再跳成「今天」。
///
/// [overrides] 是给集成测试留的缝：真机端到端用例要跑**真实的**启动路径
/// （真数据库、真通知、真时区），只把少数碰系统 UI 的部件换掉——分享面板在
/// 自动化里点不到，所以 `backupFileServiceProvider` 会在那里被换成假的。
/// 应用自己是零 override 启动的。
Future<void> main({List<Override> overrides = const <Override>[]}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 时区库的加载和建表互不依赖，先挂起来，等建完表再取结果，
  // 省掉一段首屏延迟。它内部吞掉所有异常，不会有未处理的异步错误。
  final Future<String> timeZoneFuture = initializeLocalTimeZone();

  final AppDatabase database = AppDatabase();
  final AppPreferences preferences;
  try {
    await database.ensureInitialized();
    preferences = await SettingsRepository(database).load();
  } on Object catch (error) {
    // 数据库打不开就没法假装还能用。明确报出来，比空白首屏好定位。
    // 这里是唯一允许吞掉异常并转向降级界面的地方——启动阶段的失败
    // 没有别的恢复手段，见 docs/ARCHITECTURE.md §10。
    runApp(BootstrapFailureApp(error: error));
    return;
  }

  final String timeZone = await timeZoneFuture;

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      // 复用已经打开的连接，避免第二次构造 AppDatabase。
      appDatabaseProvider.overrideWithValue(database),
      initialPreferencesProvider.overrideWithValue(preferences),
      // 集成测试注入的部分（应用启动时是空的）。
      ...overrides,
    ],
  );

  // 建渠道 + 绑定「点通知打开对应任务」的回调，必须在排第一条通知之前。
  // 渠道的重要性只在首次创建时生效，晚建就得让用户卸载重装才能改。
  final NotificationService notifications = container.read(
    notificationServiceProvider,
  );
  await notifications.initialize(
    onOpenTask: (String taskId) =>
        container.read(appRouterProvider).push(AppRoutes.taskDetail(taskId)),
  );

  // 读一次即可：这个 provider 在被创建的那一刻就把调度器挂上了，
  // 之后由调度器自己监听库变化，界面不需要反复读它。
  container.read(reminderSchedulerProvider);

  // 时区变了要重排提醒，否则跨时区之后「每天早上 9 点」会按旧时区响。
  container.read(timeZoneWatcherProvider);

  // 上次没结束的那段专注还躺在库里。这个 provider 一起来就会把常驻通知
  // 按它当前的状态重新挂上，用户划掉 App 之后仍然看得见计时还在走。
  container.read(focusNotificationSyncProvider);

  // 桌面小组件画的是一份推过去的快照：应用在跑的时候顺手推，应用不在时
  // 由系统的刷新周期重画上次那份。这里读一次把同步挂上。
  container.read(homeWidgetSyncProvider);

  debugPrint('${AppConstants.appName} 已启动，时区：$timeZone');

  runApp(
    UncontrolledProviderScope(container: container, child: const NowTodoApp()),
  );
}

/// 启动失败时的兜底界面。
///
/// 存在的意义：让用户看到「发生了什么」，而不是对着一个转圈的首屏无限等待。
class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '本地数据库打不开',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text('$error'),
                  const SizedBox(height: 12),
                  const Text('任务数据全部保存在本机，不会上传。重启应用通常会重新尝试。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
