import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/core/widget/home_widget_service.dart';
import 'package:now_todo/core/widget/home_widget_snapshot.dart';

/// Kotlin 源码目录。改 `applicationId` 时目录会跟着搬，所以集中在这里，
/// 免得三处路径各写一遍。
const String kKotlinDir =
    'android/app/src/main/kotlin/io/github/hesperyx/nowtodo';

/// 读仓库里的一份文件。
///
/// `flutter test` 的工作目录就是包根，所以直接按相对路径读。找不到时给出的
/// 提示里带上实际工作目录——工作目录变了这条测试要立刻失败，而不是静默跳过。
String readRepoFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('找不到 $path。测试的工作目录应该就是包根，实际是 ${Directory.current.path}');
  }
  return file.readAsStringSync();
}

void main() {
  late String manifest;
  late String provider;
  late String bridge;
  late String activity;
  late String widgetInfo;
  late String layout;
  late String service;

  setUpAll(() {
    manifest = readRepoFile('android/app/src/main/AndroidManifest.xml');
    provider = readRepoFile('$kKotlinDir/FocusWidgetProvider.kt');
    bridge = readRepoFile('$kKotlinDir/HomeWidgetBridge.kt');
    activity = readRepoFile('$kKotlinDir/MainActivity.kt');
    widgetInfo = readRepoFile(
      'android/app/src/main/res/xml/focus_widget_info.xml',
    );
    layout = readRepoFile('android/app/src/main/res/layout/focus_widget.xml');
    service = readRepoFile('lib/core/widget/home_widget_service.dart');
  });

  group('清单里的小组件声明', () {
    test('声明了提供者与系统那条更新广播', () {
      expect(
        manifest,
        contains('android:name=".FocusWidgetProvider"'),
        reason: '没有这条，桌面上根本不会出现这块小组件',
      );
      expect(
        manifest,
        contains('android.appwidget.action.APPWIDGET_UPDATE'),
        reason: '少了这条 intent-filter，系统不知道谁负责画它',
      );
      expect(
        manifest,
        contains('android:name="android.appwidget.provider"'),
        reason: '少了 meta-data，读不到 focus_widget_info.xml 里的配置',
      );
      expect(manifest, contains('@xml/focus_widget_info'));
    });

    test('不对外暴露：这条广播只该由系统发进来', () {
      final int start = manifest.indexOf('android:name=".FocusWidgetProvider"');
      final int end = manifest.indexOf('</receiver>', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final String receiver = manifest.substring(start, end);
      expect(receiver, contains('android:exported="false"'));
      expect(receiver, isNot(contains('android:exported="true"')));
    });
  });

  group('小组件配置与布局', () {
    test('用我们的布局，并把刷新周期写在系统认的那个字段上', () {
      expect(widgetInfo, contains('@layout/focus_widget'));
      expect(
        widgetInfo,
        contains('android:updatePeriodMillis="1800000"'),
        reason: '系统给的下限就是 30 分钟，写更小的值会被抬回来',
      );
      expect(widgetInfo, contains('android:minWidth="180dp"'));
      expect(widgetInfo, contains('android:minHeight="110dp"'));
    });

    test('Kotlin 里用到的每个 id，布局里都有', () {
      // R.id.xxx 拼错了会编译不过，但「布局改了名、Kotlin 还用老名字」这种
      // 只有两端都改了才编译得过；反过来漏一个 id，桌面上就是块空白。
      final RegExp idPattern = RegExp(r'R\.id\.([a-z0-9_]+)');
      final Set<String> ids = <String>{
        for (final RegExpMatch match in idPattern.allMatches(provider))
          match.group(1)!,
      };
      expect(ids, isNotEmpty, reason: 'provider 里一个 R.id 都没有的话，这个测试白跑');
      for (final String id in ids) {
        expect(
          layout,
          contains('@+id/$id'),
          reason: 'FocusWidgetProvider.kt 用了 R.id.$id，布局里却没有这个 id',
        );
      }
    });

    test('七根柱子都在，一天一根', () {
      for (int index = 0; index < 7; index++) {
        expect(
          layout,
          contains('@+id/widget_bar_$index'),
          reason: '第 $index 根柱子（widget_bar_$index）不见了',
        );
      }
      expect(
        provider,
        contains('R.id.widget_bar_6'),
        reason: '柱子要一根根取色，最后一根也得在 BAR_IDS 里',
      );
    });
  });

  group('Dart 与 Kotlin 之间的约定', () {
    test('发过去的每一个键，Kotlin 侧都读了', () {
      // 键名对不上不会报任何错，只会让桌面上一直空着，所以这里逐个咬住：
      // 拿 Dart 真正会发的那份 map 的键，去 Kotlin 源码里找字面量。
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        const <FocusSlice>[],
        today: dayOnlyMillis(DateTime(2026, 10, 7)),
      );
      final Map<String, Object?> payload = buildWidgetPayload(snapshot);
      expect(payload.keys, contains('today'));

      for (final String key in payload.keys) {
        expect(
          bridge,
          contains('"$key"'),
          reason: 'Dart 发了 $key，HomeWidgetBridge 里却没有读它',
        );
      }
      for (final String key in <String>[
        'today',
        'levels',
        'headline',
        'caption',
      ]) {
        expect(
          provider,
          contains('"$key"'),
          reason: '画画用的 $key 没被 FocusWidgetProvider 读出来',
        );
      }
      for (final String key in <String>[
        'paletteLight',
        'paletteDark',
        'surfaceLight',
        'surfaceDark',
        'titleLight',
        'titleDark',
        'bodyLight',
        'bodyDark',
      ]) {
        expect(
          provider,
          contains('"$key"'),
          reason: '两套主题的 $key 要能被挑出来，拼字符串是咬不住的',
        );
      }
    });

    test('通道名与方法名两边一模一样', () {
      expect(
        bridge,
        contains(MethodChannelHomeWidgetService.channelName),
        reason: 'Dart 侧的通道名是 ${MethodChannelHomeWidgetService.channelName}',
      );
      expect(
        bridge,
        contains(MethodChannelHomeWidgetService.updateMethod),
        reason: 'Dart 侧调的方法是 ${MethodChannelHomeWidgetService.updateMethod}',
      );
      expect(service, contains('now_todo/widget'));
    });

    test('两边用的是同一份 SharedPreferences', () {
      expect(
        provider,
        contains('SharedPreferences'),
        reason: '小组件只能读快照，读不到就意味着它去别处找数据了',
      );
      expect(
        bridge,
        contains('FocusWidgetProvider.prefs'),
        reason: '桥接写入与小组件读取必须是同一份文件',
      );
    });

    test('应用一起来就把通道挂上', () {
      expect(
        activity,
        contains('HomeWidgetBridge.register'),
        reason: '不挂上这条通道，推快照会一直 MissingPluginException，桌面永远不更新',
      );
    });

    test('日期对不上就当过期，不拿昨天的数字冒充今天', () {
      expect(provider, contains('startOfLocalDayMillis'));
      expect(
        provider,
        contains('focus_widget_stale_headline'),
        reason: '过期时要有一句话说明，而不是继续显示昨天的时长',
      );
    });
  });
}
