import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/theme/app_theme.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/core/widget/home_widget_service.dart';
import 'package:now_todo/core/widget/home_widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    MethodChannelHomeWidgetService.channelName,
  );
  final List<MethodCall> calls = <MethodCall>[];

  HomeWidgetSnapshot snapshotOf() => HomeWidgetSnapshot.fromSlices(
    const <FocusSlice>[],
    today: dayOnlyMillis(DateTime(2026, 10, 7)),
  );

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('MethodChannelHomeWidgetService', () {
    test('在 Android 上把整份快照发过去', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await MethodChannelHomeWidgetService(
        channel: channel,
      ).update(snapshotOf());

      expect(calls, hasLength(1));
      expect(calls.single.method, MethodChannelHomeWidgetService.updateMethod);
      final Map<Object?, Object?> arguments =
          calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['today'], dayOnlyMillis(DateTime(2026, 10, 7)));
      expect(arguments['levels'], <int>[0, 0, 0, 0, 0, 0, 0]);
      expect(arguments['headline'], '今天还没有专注');
      expect(arguments['paletteLight'], hasLength(5));
      expect(arguments['paletteDark'], hasLength(5));
    });

    test('其他平台上一个方法都不发', () async {
      // 桌面预览（Windows）上不该去碰一条不存在的通道。
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await MethodChannelHomeWidgetService(
        channel: channel,
      ).update(snapshotOf());

      expect(calls, isEmpty);
    });

    test('平台侧还没挂上时安静地过去', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw MissingPluginException('没有实现');
          });

      // 小组件是增强功能：这条路不通，应用照常用。
      await expectLater(
        MethodChannelHomeWidgetService(channel: channel).update(snapshotOf()),
        completes,
      );
    });

    test('平台侧真的出错也只记日志', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(code: 'widget_update_failed');
          });

      await expectLater(
        MethodChannelHomeWidgetService(channel: channel).update(snapshotOf()),
        completes,
      );
    });
  });

  group('NoopHomeWidgetService', () {
    test('什么都不做，也不抛', () async {
      await const NoopHomeWidgetService().update(snapshotOf());
      expect(calls, isEmpty);
    });
  });

  group('buildWidgetPayload · 跟着应用主题走的两套颜色', () {
    test('每一套都是五个档位，第一档用描边色代替', () {
      final Map<String, Object?> payload = buildWidgetPayload(snapshotOf());
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      final List<Object?> lightPalette =
          payload['paletteLight']! as List<Object?>;
      final List<Object?> darkPalette =
          payload['paletteDark']! as List<Object?>;
      expect(lightPalette, hasLength(5));
      expect(darkPalette, hasLength(5));
      expect(
        lightPalette.first,
        light.outlineVariant.toARGB32(),
        reason: 'none 档在小组件里画不了描边，直接用描边色填',
      );
      expect(darkPalette.last, dark.primary.toARGB32(), reason: 'heavy 档');
      expect(lightPalette, isNot(darkPalette), reason: '两套主题的取色不一样，发同一份就说明拿错了');
    });

    test('底色与文字色两套都在', () {
      final Map<String, Object?> payload = buildWidgetPayload(snapshotOf());
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      expect(payload['surfaceLight'], light.surfaceContainerLow.toARGB32());
      expect(payload['surfaceDark'], dark.surfaceContainerLow.toARGB32());
      expect(payload['titleLight'], light.onSurface.toARGB32());
      expect(payload['titleDark'], dark.onSurface.toARGB32());
      expect(payload['bodyLight'], light.onSurfaceVariant.toARGB32());
      expect(payload['bodyDark'], dark.onSurfaceVariant.toARGB32());
    });
  });
}
