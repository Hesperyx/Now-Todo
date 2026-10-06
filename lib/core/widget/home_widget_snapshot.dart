/// 桌面小组件要显示的那点数据。
///
/// 纯数据 + 纯函数，不 import Flutter：小组件本身在 `flutter test` 里跑不起来
/// （它由启动器绘制、进程可能已经死了），所以能测的部分必须留在这里——
/// 「今天是几号、这几天各有多久、文案怎么写」全是可以在单测里咬住的。
library;

import '../focus/focus_stats.dart';
import '../utils/time.dart';

/// 小组件上画几天。
///
/// 七天是因为它刚好是一行：一天一格，一眼能看出「这周是不是松了」。
const int kHomeWidgetDays = 7;

/// 快照窗口的第一天（本地零点）。
///
/// 查库的人和算快照的人必须用同一个窗口，否则小组件上最早那一格会莫名是空的，
/// 所以这段日期算术只写在这里一份。
int homeWidgetWindowStart(int today) {
  final DateTime local = fromUtcMillis(today);
  return dayOnlyMillis(
    DateTime(local.year, local.month, local.day - (kHomeWidgetDays - 1)),
  );
}

/// 一份可以交给平台侧的统计快照。
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.today,
    required this.seconds,
    required this.sessions,
    required this.week,
  });

  /// 快照覆盖的「今天」（本地零点毫秒）。
  ///
  /// 平台侧会拿它和当天的零点比对：对不上说明应用很久没打开过、数字已经过期，
  /// 那就只画一个「今天还没有专注」而不是把昨天的数字摆在今天。
  final int today;

  /// 今天累计的专注秒数。
  final int seconds;

  /// 今天有多少条记录，含 0 秒的那些。
  final int sessions;

  /// 最近 [kHomeWidgetDays] 天，按日期升序，最后一项就是 [today]。
  final List<FocusDaySummary> week;

  /// 和热力图同一套档位，下标对应 `lib/core/theme/heat_colors.dart` 里
  /// 那个固定的档位顺序（无记录 / 来过没计时 / 不到 15 分钟 / 15–60 分钟 /
  /// 一小时以上）。
  ///
  /// 平台侧不认颜色也不认秒数，只认这个下标。
  List<int> get levels => <int>[
    for (final FocusDaySummary day in week) heatOf(day).index,
  ];

  /// 最近这几天一点记录都没有。
  bool get isEmpty => week.every((FocusDaySummary day) => day.isEmpty);

  /// 第一行，人话。
  ///
  /// 三种状态分开写：「一条记录都没有」和「来过但没计时」不是一回事，
  /// 后者说明用户坐下来过、只是没按开始。
  String get headline => switch ((seconds, sessions)) {
    (0, 0) => '今天还没有专注',
    (0, _) => '今天来过，没计时',
    _ => '今天 ${formatSecondsText(seconds)}',
  };

  /// 第二行，人话。
  String get caption => sessions == 0 ? '去专注一段吧' : '共 $sessions 段';

  /// 交给平台侧的 map。
  ///
  /// 键名是 Dart 与 Kotlin 之间的契约，两边写错的症状是「什么也没发生」——
  /// `test/android/home_widget_declaration_test.dart` 会咬住这套键。
  Map<String, Object?> toMap() => <String, Object?>{
    'today': today,
    'seconds': seconds,
    'sessions': sessions,
    'levels': levels,
    'headline': headline,
    'caption': caption,
  };

  /// 从一段窗口里的会话算出快照。
  ///
  /// 传进来的 [slices] 要覆盖最近 [kHomeWidgetDays] 天（含今天）；窗口之外
  /// 的记录不影响结果。
  factory HomeWidgetSnapshot.fromSlices(
    Iterable<FocusSlice> slices, {
    required int today,
  }) {
    final List<FocusDaySummary> week = fillDayRange(
      summarizeDays(slices),
      from: homeWidgetWindowStart(today),
      to: today,
    );
    // 今天那一格一定在最后：上面按连续日期铺过，不会缺。
    final FocusDaySummary todaySummary = week.last;
    return HomeWidgetSnapshot(
      today: today,
      seconds: todaySummary.seconds,
      sessions: todaySummary.sessions,
      week: week,
    );
  }
}
