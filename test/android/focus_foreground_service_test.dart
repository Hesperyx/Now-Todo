// Android 侧的声明没法在单元测试里真正跑起来（要真机、要上架流程），但它们
// 是 F6a 的前提，而且漏一条的症状全都是「静默失效」：通知不出现、划掉最近
// 任务后常驻通知一起消失、Android 14+ 直接抛 SecurityException。这类错误
// 编译不报、测试不报，只有用户拿着手机才发现。
//
// 所以这里把 `android/` 下的清单当作事实来咬：读的是仓库里的文件，
// `flutter test` 的工作目录就是包根。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 读仓库里的一个文件；找不到就当场给出「工作目录在哪」的线索。
String readRepoFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('找不到 $path。测试的工作目录应该就是包根，实际是 ${Directory.current.path}');
  }
  return file.readAsStringSync();
}

void main() {
  late String manifest;
  late String service;

  setUpAll(() {
    manifest = readRepoFile('android/app/src/main/AndroidManifest.xml');
    service = readRepoFile(
      'lib/core/notifications/flutter_notification_service.dart',
    );
  });

  group('权限', () {
    test('提醒要用的四条权限都在', () {
      // 少 POST_NOTIFICATIONS：Android 13+ 一条通知都发不出来。
      // 少 RECEIVE_BOOT_COMPLETED：手机重启一次之后所有提醒静默消失。
      // 少 SCHEDULE_EXACT_ALARM：到点提醒退化成「大概那时候」。
      expect(
        manifest,
        contains('android.permission.POST_NOTIFICATIONS'),
        reason: 'Android 13+ 的运行时通知权限',
      );
      expect(
        manifest,
        contains('android.permission.RECEIVE_BOOT_COMPLETED'),
        reason: '重启后要能重新排闹钟',
      );
      expect(
        manifest,
        contains('android.permission.SCHEDULE_EXACT_ALARM'),
        reason: '精确闹钟（用户可以随时收回，代码里每次排程前会重问）',
      );
    });

    test('前台服务的两条权限都在', () {
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE'),
        reason: '常驻通知挂在前台服务上',
      );
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
        reason: 'Android 14+ 要按类型申请，专注计时属于 specialUse',
      );
    });

    test('不声明 INTERNET —— 这是一个离线应用', () {
      expect(
        manifest,
        isNot(contains('android.permission.INTERNET')),
        reason: '任何一条网络请求都该让构建先失败',
      );
    });
  });

  group('前台服务', () {
    test('服务声明的三处关键属性：划掉存活、类型、子类型说明', () {
      expect(
        manifest,
        contains('com.dexterous.flutterlocalnotifications.ForegroundService'),
        reason: 'flutter_local_notifications 的前台服务',
      );
      expect(
        manifest,
        contains('android:stopWithTask="false"'),
        reason: '划掉最近任务不算「用户想结束专注」，常驻通知必须活下来',
      );
      expect(
        manifest,
        contains('android:foregroundServiceType="specialUse"'),
        reason: 'Android 14+ 的前台服务类型',
      );
      expect(
        manifest,
        contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE'),
        reason: '上架审核要看这个子类型说明',
      );
    });

    test('清单里声明的类型覆盖得住代码里传的类型', () {
      // 两边不一致时 Android 14+ 会抛 SecurityException，而且抛在
      // startForegroundService 那一刻——用户点了「开始专注」之后。
      expect(
        manifest,
        contains('foregroundServiceType="specialUse"'),
        reason: '清单声明',
      );
      expect(
        service,
        contains(
          'AndroidServiceForegroundType.foregroundServiceTypeSpecialUse',
        ),
        reason: '代码里传给 startForegroundService 的类型必须与清单一致',
      );
    });

    test('常驻通知锁屏可见、且划不掉', () {
      expect(
        service,
        contains('visibility: NotificationVisibility.public'),
        reason: '默认的 private 在「隐藏敏感内容」下会把计时数字抹掉',
      );
      expect(
        service,
        contains('ongoing: true'),
        reason: '计时进行中的通知不该能被划掉（划掉等于关掉计时器）',
      );
    });
  });

  group('广播接收器', () {
    test('两个接收器都在，且带重启过滤器', () {
      expect(
        manifest,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
        reason: '到点把排好的通知发出来',
      );
      expect(
        manifest,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
        ),
        reason: '重启后把排好的通知重新排上',
      );
      expect(
        manifest,
        contains('android.intent.action.BOOT_COMPLETED'),
        reason: '重启广播',
      );
      expect(
        manifest,
        contains('android.intent.action.MY_PACKAGE_REPLACED'),
        reason: '应用更新后也算一次「重启」',
      );
    });
  });
}
