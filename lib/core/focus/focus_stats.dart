/// 专注统计的纯计算层。
///
/// 这里只做两件事：把「哪一刻开始的一次专注」归到一个**逻辑日**上，
/// 以及把一批记录按日 / 按小时加起来。不碰数据库、不碰 UI。
///
/// 之所以要抽出来单独测：统计口径错了不会报错，只会让用户看到一张
/// 安静地骗人的图。而口径这件事一定要能脱离数据库复现。
library;

import '../utils/time.dart';

/// 一条专注记录在统计里的最小投影。
///
/// 只放聚合真正会用到的三个字段，而不是整个 `FocusSession` 实体——
/// 这样统计函数不需要跟着表结构一起改，测试里构造数据也不用填一堆无关列。
class FocusSlice {
  const FocusSlice({
    required this.logicalDate,
    required this.startedAt,
    required this.seconds,
  });

  /// 归属的逻辑日，存的是那一天的**本地零点**（UTC 毫秒）。
  ///
  /// 由 [logicalDateFor] 在写入时算好并固化。**不能在读取时再算一遍**：
  /// 用户改一次午夜模式开关，全部历史统计的归属日会整体平移。
  final int logicalDate;

  /// 会话的开始时刻（UTC 毫秒），用于按小时分桶。
  final int startedAt;

  /// 实际专注秒数，不含暂停。
  final int seconds;
}

/// 一天在统计里的样子。
///
/// 与 [secondsByDay] 的区别是它**保留没有时长的日期**：热力图要区分
/// 「这天没打开过」和「这天开过一次但没计时」。把两者合成一个 0，
/// 用户会以为自己的记录丢了。
class FocusDaySummary {
  const FocusDaySummary({
    required this.day,
    required this.seconds,
    required this.sessions,
  });

  /// 这一天（本地零点，UTC 毫秒），与 [FocusSlice.logicalDate] 同构。
  final int day;

  /// 这一天累计的专注秒数。
  final int seconds;

  /// 这一天有多少条记录，含 0 秒的那些。
  final int sessions;

  /// 这一天完全没有记录。
  bool get isEmpty => sessions == 0;

  /// 这一天有时长。
  bool get hasTime => seconds > 0;
}

/// 一格热力格子的强度分档。
///
/// 阈值是**固定**的而不是按当批数据算分位：热力图的意义在于跨周可比，
/// 按分位算的话同一张图昨天和今天的长相会不一样，图例也就没法写。
enum FocusHeat { none, zero, light, medium, heavy }

/// 算出一次专注归属的逻辑日。
///
/// 开午夜模式后，凌晨 [midnightEndHour] 点之前开始的会话算作**前一天**——
/// 因为对熬夜的人来说，「昨晚 1 点」属于昨晚，不属于今天。
///
/// [midnightEndHour] 取 0 时等价于关闭：`hour < 0` 永不成立，全部归当天。
/// 这是刻意的——开关的一次表达，不用两条分支。
///
/// 返回那一天的本地零点（UTC 毫秒），与 `focus_sessions.logical_date` 同构。
int logicalDateFor(
  int startedAtMillis, {
  required bool midnightMode,
  int midnightEndHour = 4,
}) {
  final DateTime local = fromUtcMillis(startedAtMillis);
  // 用 DateTime(y, m, d - 1) 而不是 subtract(Duration(days: 1))：后者在
  // 夏令时切换那天会因为「一天不是 24 小时」而落到别的小时上，
  // 再取零点就可能偏掉一天。
  final DateTime day = midnightMode && local.hour < midnightEndHour
      ? DateTime(local.year, local.month, local.day - 1)
      : local;
  return dayOnlyMillis(day);
}

/// [dayMillis] 的前一天（同样是本地零点）。
int previousLocalDay(int dayMillis) {
  final DateTime day = fromUtcMillis(dayMillis);
  return dayOnlyMillis(DateTime(day.year, day.month, day.day - 1));
}

/// 按逻辑日汇总秒数。键是 [FocusSlice.logicalDate]。
///
/// 只保留秒数大于 0 的日期：0 秒的会话不该在图上占一格。
Map<int, int> secondsByDay(Iterable<FocusSlice> slices) {
  final Map<int, int> result = <int, int>{};
  for (final FocusSlice slice in slices) {
    if (slice.seconds <= 0) continue;
    result[slice.logicalDate] =
        (result[slice.logicalDate] ?? 0) + slice.seconds;
  }
  return result;
}

/// 按**一天中的第几小时**汇总秒数，键是 0–23。
///
/// 一次跨小时的会话会被**切开**，分别落进它真正占据的那几个小时，
/// 而不是整块算给开始那一刻。理由：这是用来回答「我几点最坐得住」的，
/// 把 23:30 开始的 90 分钟全算给 23 点会把这个结论弄反。
Map<int, int> secondsByHourOfDay(Iterable<FocusSlice> slices) {
  final Map<int, int> result = <int, int>{};
  for (final FocusSlice slice in slices) {
    if (slice.seconds <= 0) continue;
    int left = slice.seconds;
    DateTime cursor = fromUtcMillis(slice.startedAt);
    while (left > 0) {
      // 下一个整点。夏令时可能让这一小时变成 0 分钟或 120 分钟，
      // difference() 会照实给出，下面的 left <= 0 与步进都能兜住。
      final DateTime nextHour = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour + 1,
      );
      final int toBoundary = nextHour.difference(cursor).inSeconds;
      if (toBoundary <= 0) {
        // 理论上到不了这里（时间不可能不前进）。真到了就整块收尾，
        // 不能死循环。
        result[cursor.hour] = (result[cursor.hour] ?? 0) + left;
        break;
      }
      final int take = left < toBoundary ? left : toBoundary;
      result[cursor.hour] = (result[cursor.hour] ?? 0) + take;
      left -= take;
      cursor = nextHour;
    }
  }
  return result;
}

/// 一组记录的总秒数。
int totalSeconds(Iterable<FocusSlice> slices) {
  int sum = 0;
  for (final FocusSlice slice in slices) {
    if (slice.seconds > 0) sum += slice.seconds;
  }
  return sum;
}

/// 到今天为止的连续天数。
///
/// 口径：从 [today] 往前数，连续每天都有专注记录的天数。**今天还没开始
/// 专注不算断**——凌晨打开应用时把昨天之前的连续记录清成 0，用户会觉得
/// 自己在被惩罚。所以今天为 0 时从昨天开始数。
///
/// 今天和昨天都没有记录，连续天数才是 0。
int currentStreakDays(Map<int, int> secondsByDay, {required int today}) {
  bool hasData(int day) => (secondsByDay[day] ?? 0) > 0;

  int cursor = today;
  if (!hasData(cursor)) {
    cursor = previousLocalDay(cursor);
  }

  int days = 0;
  while (hasData(cursor)) {
    days++;
    cursor = previousLocalDay(cursor);
  }
  return days;
}

/// 历史上最长的一段连续天数。
///
/// 与 [currentStreakDays] 分开算：成就徽章要的是「有没有达成过」，
/// 而首页显示的是「现在连续多少天」。
int longestStreakDays(Map<int, int> secondsByDay) {
  final List<int> days =
      secondsByDay.entries
          .where((MapEntry<int, int> e) => e.value > 0)
          .map((MapEntry<int, int> e) => e.key)
          .toList()
        ..sort();

  int best = 0;
  int run = 0;
  int? previous;
  for (final int day in days) {
    run = (previous != null && previousLocalDay(day) == previous) ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// 把记录按日汇总，只含有记录的日期，按日升序。
///
/// 与 [secondsByDay] 的分工：那个只关心「画图时哪些格子要上色」，
/// 这个还要回答「哪些格子有记录」。热力图两者都要。
List<FocusDaySummary> summarizeDays(Iterable<FocusSlice> slices) {
  final Map<int, int> seconds = <int, int>{};
  final Map<int, int> counts = <int, int>{};
  for (final FocusSlice slice in slices) {
    if (slice.seconds > 0) {
      seconds[slice.logicalDate] =
          (seconds[slice.logicalDate] ?? 0) + slice.seconds;
    }
    counts[slice.logicalDate] = (counts[slice.logicalDate] ?? 0) + 1;
  }
  final List<int> days = counts.keys.toList()..sort();
  return <FocusDaySummary>[
    for (final int day in days)
      FocusDaySummary(
        day: day,
        seconds: seconds[day] ?? 0,
        sessions: counts[day] ?? 0,
      ),
  ];
}

/// 把日汇总铺成从 [from] 到 [to]（含两端）的**连续**日期。
///
/// 热力图要画满每一个格子。缺的日期是「那天没记录」，不是「那天不存在」，
/// 所以补的是空白的一天而不是跳过——跳过会把整张图的星期列错位。
List<FocusDaySummary> fillDayRange(
  Iterable<FocusDaySummary> days, {
  required int from,
  required int to,
}) {
  final Map<int, FocusDaySummary> byDay = <int, FocusDaySummary>{
    for (final FocusDaySummary day in days) day.day: day,
  };
  final DateTime last = fromUtcMillis(to);
  final List<FocusDaySummary> result = <FocusDaySummary>[];
  DateTime cursor = fromUtcMillis(from);
  while (!cursor.isAfter(last)) {
    final int millis = dayOnlyMillis(cursor);
    result.add(
      byDay[millis] ?? FocusDaySummary(day: millis, seconds: 0, sessions: 0),
    );
    // 用 DateTime(y, m, d + 1) 而不是 add(Duration(days: 1))：夏令时那天
    // 一天不是 24 小时，加固定时长会漂到别的小时上，取零点就偏了一天。
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return result;
}

/// 这一天所在那一周的周一（本地零点）。
int weekStartOf(int dayMillis) {
  final DateTime day = fromUtcMillis(dayMillis);
  return dayOnlyMillis(
    DateTime(day.year, day.month, day.day - (day.weekday - 1)),
  );
}

/// 这一天所在那个月的 1 号（本地零点）。
int monthStartOf(int dayMillis) {
  final DateTime day = fromUtcMillis(dayMillis);
  return dayOnlyMillis(DateTime(day.year, day.month));
}

/// 统计页上「看哪一档」的粒度。
enum FocusSpan { day, week, month }

/// 一段时间（一天 / 一周 / 一月）的合计。
class FocusPeriodTotal {
  const FocusPeriodTotal({
    required this.start,
    required this.seconds,
    required this.sessions,
    required this.daysWithData,
  });

  /// 这一段的起点（本地零点）：日就是那天，周是周一，月是 1 号。
  final int start;

  /// 这一段累计的专注秒数。
  final int seconds;

  /// 这一段有多少条记录。
  final int sessions;

  /// 这一段里有几天真的有时长。用来判断「这一段是不是空的」——
  /// 只有记录没有时长的日子不该撑起一根柱子。
  final int daysWithData;
}

/// 按 [span] 把日汇总合成一段一段，按起点升序。
///
/// 只产出**有记录**的段：中间某周一条记录都没有时不会凭空多一根 0 的柱子，
/// 那会让整张图被拉长成一堆空档。要判断某一段有没有时长看 [FocusPeriodTotal.daysWithData]。
List<FocusPeriodTotal> groupBySpan(
  Iterable<FocusDaySummary> days,
  FocusSpan span,
) {
  int bucketOf(int day) => switch (span) {
    FocusSpan.day => day,
    FocusSpan.week => weekStartOf(day),
    FocusSpan.month => monthStartOf(day),
  };

  final Map<int, int> seconds = <int, int>{};
  final Map<int, int> sessions = <int, int>{};
  final Map<int, int> withData = <int, int>{};
  for (final FocusDaySummary day in days) {
    final int key = bucketOf(day.day);
    seconds[key] = (seconds[key] ?? 0) + day.seconds;
    sessions[key] = (sessions[key] ?? 0) + day.sessions;
    if (day.hasTime) withData[key] = (withData[key] ?? 0) + 1;
  }
  final List<int> keys = seconds.keys.toList()..sort();
  return <FocusPeriodTotal>[
    for (final int key in keys)
      FocusPeriodTotal(
        start: key,
        seconds: seconds[key] ?? 0,
        sessions: sessions[key] ?? 0,
        daysWithData: withData[key] ?? 0,
      ),
  ];
}

/// 少于这个秒数算「少」。
const int _lightSeconds = 15 * 60;

/// 达到这个秒数算「多」。
const int _heavySeconds = 60 * 60;

/// 一天的热力档位。
///
/// [FocusHeat.zero] 单独占一档：「有记录但一秒都没计时」和「这天什么都没干」
/// 是两件事，前者说明用户来过，后者说明没来。
FocusHeat heatOf(FocusDaySummary day) {
  if (day.isEmpty) return FocusHeat.none;
  if (!day.hasTime) return FocusHeat.zero;
  if (day.seconds < _lightSeconds) return FocusHeat.light;
  if (day.seconds < _heavySeconds) return FocusHeat.medium;
  return FocusHeat.heavy;
}

/// 秒数最多的那一小时（0–23）。
///
/// 全天没数据或全是 0 时返回 null——图上画不出「最坐得住的一小时」，
/// 硬给一个 0 点等于编了一句假话。并列时取更早的那个小时。
int? peakHour(Map<int, int> secondsByHourOfDay) {
  int? best;
  int bestSeconds = 0;
  final List<int> hours = secondsByHourOfDay.keys.toList()..sort();
  for (final int hour in hours) {
    final int value = secondsByHourOfDay[hour] ?? 0;
    if (value > bestSeconds) {
      bestSeconds = value;
      best = hour;
    }
  }
  return best;
}

/// 统计页的窗口长度：最近 365 天（含今天）。
///
/// 一年而不是「全部历史」：一次查询的把控在上限可估的范围内，而一整年的
/// 热力图正好一屏能讲清楚；再久远的数据对「我最近怎么样」没有帮助。
const int kFocusStatsWindowDays = 365;

/// 统计页需要的一份数据，全部由纯函数算好。
///
/// 有意做成「读一次、算一遍」的快照而不是一串 `Stream`：统计看的是历史，
/// 它不需要逐秒跳动。正在跑的那一段按构造这份快照的时刻计入。
class FocusStats {
  FocusStats._({
    required this.from,
    required this.to,
    required this.days,
    required this.hours,
    required this.slices,
  });

  /// 从一批记录构造，顺带把日汇总补齐成 [from]–[to] 的连续日期。
  factory FocusStats.from({
    required Iterable<FocusSlice> slices,
    required int from,
    required int to,
  }) {
    final List<FocusSlice> list = slices.toList();
    return FocusStats._(
      from: from,
      to: to,
      days: fillDayRange(summarizeDays(list), from: from, to: to),
      hours: secondsByHourOfDay(list),
      slices: list,
    );
  }

  /// 窗口的第一天（本地零点）。
  final int from;

  /// 窗口的最后一天，正常情况下是今天。
  final int to;

  /// 窗口内**连续**的每一天，长度是 `to - from` 的天数。
  final List<FocusDaySummary> days;

  /// 按一天中的第几小时汇总，键 0–23。
  final Map<int, int> hours;

  /// 窗口内的原始记录，用来数条数。
  final List<FocusSlice> slices;

  /// 一条记录都没有。
  ///
  /// 注意与「有记录但都是 0 秒」的区别：那种情况 [sessionCount] > 0、
  /// [total] == 0，页面该显示数据而不是空态。
  bool get isEmpty => slices.isEmpty;

  /// 窗口内的总秒数。
  int get total => totalSeconds(slices);

  /// 窗口内的记录条数。
  int get sessionCount => slices.length;

  /// 窗口内有几天真的有时长。
  int get daysWithData =>
      days.where((FocusDaySummary day) => day.hasTime).length;

  /// 到 [now] 为止的连续天数。
  int currentStreak(int today) => currentStreakDays(<int, int>{
    for (final FocusDaySummary day in days)
      if (day.hasTime) day.day: day.seconds,
  }, today: today);

  /// 历史上最长的一段连续天数（只在这个窗口内）。
  int longestStreak() => longestStreakDays(<int, int>{
    for (final FocusDaySummary day in days)
      if (day.hasTime) day.day: day.seconds,
  });

  /// 取某一天的汇总，窗口外或没有这一天时返回 null。
  FocusDaySummary? dayAt(int dayMillis) {
    for (final FocusDaySummary day in days) {
      if (day.day == dayMillis) return day;
    }
    return null;
  }
}
