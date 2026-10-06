/// 成就徽章的纯计算层。
///
/// 这里**不落表**：解锁状态每次都由专注记录现推出来。存一份「解锁记录」
/// 就要额外回答「改了判定规则之后，已经解锁的还算不算」；现推的答案显然易见
/// ——按新规则重算一遍。代价是每次打开徽章页要扫一遍历史记录，而这份记录
/// 的量级（一年几千条）在一次内存聚合的量级之内（见 `focus_stats.dart`）。
///
/// 判定是纯函数：给同一批记录必然得到同一结果，所以口径能脱离数据库单测。
library;

import '../utils/time.dart';
import 'focus_stats.dart';

/// 徽章计量的单位，只影响文案。
enum AchievementUnit {
  times('次'),
  days('天'),
  hours('小时'),
  minutes('分钟');

  const AchievementUnit(this.label);

  /// 显示在进度旁边的单位。
  final String label;
}

/// 判定一枚徽章需要的事实，全部由一批记录现算。
///
/// 做成一个装好的对象而不是让每枚徽章各自扫一遍记录：14 枚徽章各扫一遍
/// 就是 14 遍 O(n)，而这些派生值其实彼此共用。
///
/// **口径**：数条数的徽章（`sessions_*`、`day_four`）连 0 秒的记录一起数——
/// 一条 0 秒的记录是「用户确实启动过计时器」的证据，统计页的「来过没计时」
/// 也不把它当没来过；求时长的徽章（`hours_*`、`deep_day`、`marathon`）只看
/// 秒数，所以那种记录在时长类里一点忙都帮不上。
class AchievementFacts {
  AchievementFacts._({
    required this.totalFocusSeconds,
    required this.sessionCount,
    required this.daysWithData,
    required this.currentStreak,
    required this.longestStreak,
    required this.bestDaySeconds,
    required this.bestDaySessions,
    required this.longestSessionSeconds,
    required this.earlySessions,
    required this.lateSessions,
  });

  /// 从**全部**记录（不是某个窗口）算出所有派生值。
  ///
  /// [today] 用来算「现在连续多少天」。与统计页不同，这里有意不截 365 天：
  /// 「累计 100 小时」这种徽章算的是一辈子的账，截窗口会让已经达成的徽章
  /// 在某天忽然又锁上。
  factory AchievementFacts.from({
    required Iterable<FocusSlice> slices,
    required int today,
  }) {
    final List<FocusSlice> list = slices.toList();

    final Map<int, int> byDay = secondsByDay(list);
    final Map<int, int> sessionsPerDay = <int, int>{};
    for (final FocusSlice slice in list) {
      sessionsPerDay[slice.logicalDate] =
          (sessionsPerDay[slice.logicalDate] ?? 0) + 1;
    }

    int bestDaySeconds = 0;
    for (final int seconds in byDay.values) {
      if (seconds > bestDaySeconds) bestDaySeconds = seconds;
    }
    int bestDaySessions = 0;
    for (final int count in sessionsPerDay.values) {
      if (count > bestDaySessions) bestDaySessions = count;
    }

    int longestSessionSeconds = 0;
    int early = 0;
    int late = 0;
    for (final FocusSlice slice in list) {
      if (slice.seconds > longestSessionSeconds) {
        longestSessionSeconds = slice.seconds;
      }
      // 「几点开始」用的是开始那一刻的钟点，不是整段落在哪里：
      // 徽章问的是「你有没有在这个时候坐下来」。
      final int hour = fromUtcMillis(slice.startedAt).hour;
      if (hour < 6) early++;
      if (hour >= 22) late++;
    }

    return AchievementFacts._(
      totalFocusSeconds: totalSeconds(list),
      sessionCount: list.length,
      daysWithData: byDay.length,
      currentStreak: currentStreakDays(byDay, today: today),
      longestStreak: longestStreakDays(byDay),
      bestDaySeconds: bestDaySeconds,
      bestDaySessions: bestDaySessions,
      longestSessionSeconds: longestSessionSeconds,
      earlySessions: early,
      lateSessions: late,
    );
  }

  /// 累计专注秒数（0 秒的记录不计）。
  ///
  /// 名字带上 `Focus` 是因为 `focus_stats.dart` 里有个同名函数
  /// `totalSeconds()`；字段叫 `totalSeconds` 会把它挡在类作用域外。
  final int totalFocusSeconds;

  /// 全部记录条数，含 0 秒的那些。
  final int sessionCount;

  /// 有多少天真的有时长。
  final int daysWithData;

  /// 到「今天」为止的连续天数。
  final int currentStreak;

  /// 历史上最长的一段连续天数。
  final int longestStreak;

  /// 单日最长的那一天有多少秒。
  final int bestDaySeconds;

  /// 单日最多有几条记录（含 0 秒的）。
  final int bestDaySessions;

  /// 单段最长的秒数。
  final int longestSessionSeconds;

  /// 开始时刻在早上 6 点之前的记录条数。
  final int earlySessions;

  /// 开始时刻在晚上 10 点及以后的记录条数。
  final int lateSessions;
}

/// 一枚徽章的定义。
///
/// 判定的形状统一成「一个计数器 + 一个目标」：进度条、`3 / 10 次` 这样的
/// 提示、解锁与否，全都由这两个值推出来，不用每枚徽章各写一套 UI 分支。
class Achievement {
  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.unit,
    required this.target,
    required this.valueOf,
  });

  /// 稳定的标识。**不要改**：将来要拿去导出去了就是它。
  final String key;

  /// 徽章名。
  final String title;

  /// 一句话说明怎么拿到。
  final String description;

  /// 计量单位。
  final AchievementUnit unit;

  /// 达到多少算解锁。
  final int target;

  /// 从事实里取当前值（与 [unit] 同一个量纲）。
  final int Function(AchievementFacts facts) valueOf;
}

/// 全部徽章，按「从易到难」排。
///
/// 顺序是刻意排的：徽章页不分组，一屏里最能传达「这条路有多长」的就是难度递增。
const List<Achievement> kAchievements = <Achievement>[
  Achievement(
    key: 'first_session',
    title: '第一步',
    description: '启动第一段专注。最难的从来是坐下来。',
    unit: AchievementUnit.times,
    target: 1,
    valueOf: _sessions,
  ),
  Achievement(
    key: 'hours_1',
    title: '满一小时',
    description: '累计专注满 1 小时。',
    unit: AchievementUnit.hours,
    target: 1,
    valueOf: _totalHours,
  ),
  Achievement(
    key: 'streak_3',
    title: '连续三天',
    description: '连着三天都有专注记录。',
    unit: AchievementUnit.days,
    target: 3,
    valueOf: _longestStreak,
  ),
  Achievement(
    key: 'early_bird',
    title: '早起鸟',
    description: '在早上 6 点之前开始过一段专注。',
    unit: AchievementUnit.times,
    target: 1,
    valueOf: _earlySessions,
  ),
  Achievement(
    key: 'night_owl',
    title: '夜猫子',
    description: '在晚上 10 点之后开始过一段专注。',
    unit: AchievementUnit.times,
    target: 1,
    valueOf: _lateSessions,
  ),
  Achievement(
    key: 'sessions_10',
    title: '十段',
    description: '完成 10 段专注。',
    unit: AchievementUnit.times,
    target: 10,
    valueOf: _sessions,
  ),
  Achievement(
    key: 'hours_10',
    title: '满十小时',
    description: '累计专注满 10 小时。',
    unit: AchievementUnit.hours,
    target: 10,
    valueOf: _totalHours,
  ),
  Achievement(
    key: 'day_four',
    title: '一天四段',
    description: '在一天里完成了 4 段专注。',
    unit: AchievementUnit.times,
    target: 4,
    valueOf: _bestDaySessions,
  ),
  Achievement(
    key: 'streak_7',
    title: '连续一周',
    description: '连着七天都有专注记录。',
    unit: AchievementUnit.days,
    target: 7,
    valueOf: _longestStreak,
  ),
  Achievement(
    key: 'marathon',
    title: '长跑',
    description: '有一段专注持续了 90 分钟以上。',
    unit: AchievementUnit.minutes,
    target: 90,
    valueOf: _longestSessionMinutes,
  ),
  Achievement(
    key: 'deep_day',
    title: '深度一天',
    description: '一天里累计专注满 3 小时。',
    unit: AchievementUnit.minutes,
    target: 180,
    valueOf: _bestDayMinutes,
  ),
  Achievement(
    key: 'sessions_100',
    title: '一百段',
    description: '完成 100 段专注。',
    unit: AchievementUnit.times,
    target: 100,
    valueOf: _sessions,
  ),
  Achievement(
    key: 'hours_100',
    title: '满一百小时',
    description: '累计专注满 100 小时。',
    unit: AchievementUnit.hours,
    target: 100,
    valueOf: _totalHours,
  ),
  Achievement(
    key: 'streak_30',
    title: '连续一个月',
    description: '连着三十天都有专注记录。',
    unit: AchievementUnit.days,
    target: 30,
    valueOf: _longestStreak,
  ),
];

int _sessions(AchievementFacts facts) => facts.sessionCount;
int _totalHours(AchievementFacts facts) => facts.totalFocusSeconds ~/ 3600;
int _longestStreak(AchievementFacts facts) => facts.longestStreak;
int _earlySessions(AchievementFacts facts) => facts.earlySessions;
int _lateSessions(AchievementFacts facts) => facts.lateSessions;
int _bestDaySessions(AchievementFacts facts) => facts.bestDaySessions;
int _bestDayMinutes(AchievementFacts facts) => facts.bestDaySeconds ~/ 60;
int _longestSessionMinutes(AchievementFacts facts) =>
    facts.longestSessionSeconds ~/ 60;

/// 一枚徽章加上「现在到哪儿了」。
class AchievementProgress {
  const AchievementProgress({required this.achievement, required this.value});

  /// 徽章定义。
  final Achievement achievement;

  /// 当前值，与 `achievement.unit` 同一个量纲。不会被截到目标值以下——
  /// 「累计 3 小时 20 分」比「3 小时」更诚实，超出部分由 `ratio` 收住。
  final int value;

  /// 是否达成。
  bool get unlocked => value >= achievement.target;

  /// 进度，0–1。
  double get ratio {
    final int target = achievement.target;
    if (target <= 0) return 1;
    final int capped = value < 0 ? 0 : (value > target ? target : value);
    return capped / target;
  }

  /// 还差多少（已达成时是 0）。
  int get remaining {
    final int left = achievement.target - value;
    return left > 0 ? left : 0;
  }

  /// 进度文案：`3 / 10 次`。
  String get progressText {
    final int target = achievement.target;
    final int capped = value < 0 ? 0 : (value > target ? target : value);
    return '$capped / $target ${achievement.unit.label}';
  }
}

/// 把一批记录判成全部徽章的进度，顺序与 [kAchievements] 一致。
List<AchievementProgress> evaluateAchievements(AchievementFacts facts) {
  return <AchievementProgress>[
    for (final Achievement achievement in kAchievements)
      AchievementProgress(
        achievement: achievement,
        value: achievement.valueOf(facts),
      ),
  ];
}

/// 已解锁的枚数。
int unlockedCount(Iterable<AchievementProgress> progress) {
  int count = 0;
  for (final AchievementProgress item in progress) {
    if (item.unlocked) count++;
  }
  return count;
}

/// 徽章页要的全部东西：算进度用的那份事实，加上 14 枚的进度。
///
/// 页面同时要「一条记录都没有」和「解锁了几枚」两件事，而进度列表本身
/// 永远是 14 条、分辨不出前者——所以事实对象一起带出来，让页面别再猜。
class AchievementBoard {
  const AchievementBoard({required this.facts, required this.progress});

  /// 这份进度是从哪份事实算出来的。
  final AchievementFacts facts;

  /// 全部徽章的进度，顺序与 [kAchievements] 一致。
  final List<AchievementProgress> progress;

  /// 一条专注记录都没有。
  bool get isEmpty => facts.sessionCount == 0;

  /// 已解锁枚数。
  int get unlocked => unlockedCount(progress);

  /// 徽章总数。
  int get total => progress.length;
}
