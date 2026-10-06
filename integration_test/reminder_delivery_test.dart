// 真机上的提醒送达验证（M5 验收第一条）。
//
// 单元测试只能证明「我们调了 zonedSchedule」，证明不了系统真的把通知
// 发出来了。这里补上后半段：排一条几秒后的提醒 → 等它到点 → 再问系统
// 「你还欠我哪些通知」。系统派发之后会把这条从待排清单里摘掉
// （`ScheduledNotificationReceiver` 里调的 `removeNotificationFromCache`），
// 摘掉就说明确实到点触发了。
//
// 跑法（需要设备在线，`flutter devices` 能看到）：
//
//   adb shell pm grant io.github.hesperyx.nowtodo android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/reminder_delivery_test.dart -d <deviceId>
//
// 先授权是因为系统弹窗在自动化的用例里点不到；没授权时用例会以
// 「通知权限没给」的 reason 失败，而不是误报成排程坏了。

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:now_todo/core/notifications/flutter_notification_service.dart';
import 'package:now_todo/core/notifications/notification_ids.dart';
import 'package:now_todo/core/notifications/timezone_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 插件是单例工厂，这里拿到的是 FlutterNotificationService 内部同一个实例，
  // 所以它看到的待排清单就是应用真实排出去的那一份。
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  testWidgets('到点之后系统真的把提醒发出来了', (WidgetTester tester) async {
    final String zone = await initializeLocalTimeZone();
    final FlutterNotificationService service = FlutterNotificationService();
    await service.initialize();

    expect(
      await service.areNotificationsEnabled(),
      isTrue,
      reason:
          '系统没有允许通知，这条用例证明不了任何东西。'
          '先跑 adb shell pm grant io.github.hesperyx.nowtodo '
          'android.permission.POST_NOTIFICATIONS',
    );

    final int id = NotificationIds.forReminder('integration-probe');
    final DateTime at = DateTime.now().add(const Duration(seconds: 6));

    await service.schedule(
      notificationId: id,
      title: '提醒送达自检',
      body: '看到这条说明排程链路是通的（时区 $zone）。',
      at: at,
      channelId: NotificationChannels.reminders,
      payload: 'integration-probe',
    );

    final Iterable<int> before = (await plugin.pendingNotificationRequests())
        .map((PendingNotificationRequest r) => r.id);
    expect(before, contains(id), reason: '排完之后系统应该欠我们一条提醒');

    // 等到点之后再看一次。用 runAsync 逃出 testWidgets 的假时钟区，
    // 否则这个 Future.delayed 永远不会真的走完。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 15)),
    );

    final Iterable<int> after = (await plugin.pendingNotificationRequests())
        .map((PendingNotificationRequest r) => r.id);
    expect(after, isNot(contains(id)), reason: '到点 15 秒后这条还挂在待排清单里，说明系统根本没触发它');

    // 收尾：通知栏里那条也撤掉，别留在设备上。
    await service.cancel(id);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
