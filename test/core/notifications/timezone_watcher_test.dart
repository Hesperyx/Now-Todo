// 时区监听的用例。
//
// 这里验证的是「什么时候该重排提醒」这个判定，不碰平台通道——设备时区
// 由注入的假函数给出，`tz.local` 是真的（`timezone` 是纯 Dart 包）。
//
// 为什么值得单测：这套逻辑错了不会报错，只会让提醒在错误的时间响。
// 跨时区之后没重排的话，用户的「每天 9 点」会变成别的钟点。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/notifications/timezone_bootstrap.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 这一步同时把时区数据库加载进来；测试环境读不到平台通道，
    // 它会安静地保持默认，正是我们要的起点。
    await initializeLocalTimeZone();
    tz.setLocalLocation(tz.UTC);
  });

  tearDown(() {
    tz.setLocalLocation(tz.UTC);
  });

  TimeZoneWatcher watcher(
    Future<String?> Function() read, {
    required List<String> seen,
  }) {
    return TimeZoneWatcher(
      readTimezone: read,
      onChanged: (String identifier) async => seen.add(identifier),
    );
  }

  test('设备时区变了就回调一次，并把本地时区换过去', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Asia/Shanghai', seen: seen);

    expect(await w.check(), isTrue);
    expect(seen, <String>['Asia/Shanghai']);
    expect(tz.local.name, 'Asia/Shanghai');

    w.dispose();
  });

  test('时区没变时不重复回调', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Asia/Shanghai', seen: seen);

    expect(await w.check(), isTrue);
    expect(await w.check(), isFalse);
    expect(await w.check(), isFalse);
    expect(seen, hasLength(1));

    w.dispose();
  });

  test('换到另一个时区时会再回调一次', () async {
    final List<String> seen = <String>[];
    String deviceZone = 'Asia/Shanghai';
    final TimeZoneWatcher w = watcher(() async => deviceZone, seen: seen);

    await w.check();
    deviceZone = 'Europe/Berlin';
    expect(await w.check(), isTrue);

    expect(seen, <String>['Asia/Shanghai', 'Europe/Berlin']);
    expect(tz.local.name, 'Europe/Berlin');

    w.dispose();
  });

  test('读不到设备时区时什么都不做，也不回调', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => null, seen: seen);

    expect(await w.check(), isFalse);
    expect(seen, isEmpty);
    expect(tz.local.name, 'UTC');

    w.dispose();
  });

  test('标识符不在时区数据库里时保持原样，也不回调', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Mars/Olympus', seen: seen);

    expect(await w.check(), isFalse);
    expect(seen, isEmpty);
    expect(tz.local.name, 'UTC');

    w.dispose();
  });

  test('回到前台会立刻查一次，其它状态不查', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Asia/Tokyo', seen: seen)
      ..start();

    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(seen, <String>['Asia/Tokyo']);

    w.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(seen, hasLength(1));

    w.dispose();
  });

  test('dispose 之后回到前台不再回调', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Asia/Tokyo', seen: seen)
      ..start();

    w.dispose();
    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(seen, isEmpty);
  });

  test('没 start 过就 poke 它是惰性的', () async {
    final List<String> seen = <String>[];
    final TimeZoneWatcher w = watcher(() async => 'Asia/Tokyo', seen: seen);

    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(seen, isEmpty);

    w.dispose();
  });
}
