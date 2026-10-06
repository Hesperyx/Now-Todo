import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 初始化时区数据库，并把 `tz.local` 设成本机时区。
///
/// **不设会静默出错**：`initializeTimeZones()` 之后 `tz.local` 是 UTC，
/// 而 `zonedSchedule` 要的是 `TZDateTime`。用户说「明天早上 9 点」，
/// 若按 UTC 解释，东八区的人会在下午 5 点收到提醒——差 8 小时，
/// 而且不会抛任何异常。
///
/// 用 `latest_all` 而不是 `latest`：前者包含被废弃的历史别名
/// （比如 `Asia/Calcutta`）。不同 Android 厂商返回的标识符不统一，
/// 少一个查表失败就会退回 UTC。多出来的体积不到 0.1 MB。
///
/// 时区数据库只需要加载一次，所以这件事不放在 [TimeZoneWatcher] 里做。
///
/// 返回最终生效的时区名，方便日志核对。
Future<String> initializeLocalTimeZone() async {
  tzdata.initializeTimeZones();
  final String? identifier = await _readDeviceTimeZone();
  if (identifier != null) {
    _setLocalLocation(identifier);
  }
  return tz.local.name;
}

/// 盯着设备时区有没有变，变了就通知调用方重排提醒。
///
/// `flutter_timezone` 只提供「读一次」，没有变更广播，所以只能轮询。这里
/// 轮询是合适的：一次读取是很轻的平台调用，而时区变化的频率是「用户出国」
/// 那个级别。
///
/// 真正的触发点是**回到前台**——用户落地、开机、重新打开应用，那时时区
/// 已经变了，定时轮询只是防止应用长时间停在前台时的兜底。
///
/// **为什么非重排不可**：提醒的墙上时间是用户给的（「每天 9 点」），而
/// `zonedSchedule` 要的是绝对时刻。`tz.local` 不更新的话，跨时区之后这条
/// 提醒仍按旧时区换算——早八点的提醒会变成下午四点响，而且不会有任何报错。
class TimeZoneWatcher with WidgetsBindingObserver {
  TimeZoneWatcher({
    required this.onChanged,
    this.interval = const Duration(minutes: 10),
    Future<String?> Function()? readTimezone,
  }) : _readTimezone = readTimezone ?? _readDeviceTimeZone;

  /// 时区变化后调用，参数是新的时区标识符。
  final Future<void> Function(String identifier) onChanged;

  /// 兜底轮询间隔。
  final Duration interval;

  /// 读设备时区。可注入是为了能单测——测试环境里平台通道不存在。
  final Future<String?> Function() _readTimezone;

  Timer? _timer;
  bool _observing = false;
  String? _current;

  void start() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `_observing` 为 false 说明还没 `start()` 或已经 `dispose()`。
    // 这两种情况下都该是惰性的：框架不会再调到这里，但这个方法本身是公开的。
    if (!_observing) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
    }
  }

  /// 立刻查一次，返回是否真的变了。
  Future<bool> check() async {
    final String? identifier = await _readTimezone();
    if (identifier == null || identifier == _current) return false;
    if (!_setLocalLocation(identifier)) return false;
    _current = identifier;
    await onChanged(identifier);
    return true;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }
}

/// 读设备时区的标识符。读不到返回 null，由调用方保持现状。
Future<String?> _readDeviceTimeZone() async {
  try {
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } on Object catch (error) {
    // 取不到就保持默认，不要因此让应用起不来：提醒的时间会偏，
    // 但用户至少能用。
    debugPrint('读取设备时区失败，继续用 ${tz.local.name}：$error');
    return null;
  }
}

/// 把 `tz.local` 设成 [identifier]，返回是否成功。
///
/// 标识符来自系统，理论上都在数据库里，但厂商的自定义时区标识符确实会
/// 出现查不到的情况，所以这里要兜住。
bool _setLocalLocation(String identifier) {
  try {
    tz.setLocalLocation(tz.getLocation(identifier));
    return true;
  } on Object catch (error) {
    debugPrint('时区标识符 $identifier 不在数据库里，保持 ${tz.local.name}：$error');
    return false;
  }
}
