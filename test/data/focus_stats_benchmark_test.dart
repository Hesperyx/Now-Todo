// 365 天、1095 段专注下的统计聚合压测。
//
// 对应 `docs/MILESTONES.md` F4 的验收第一条「一年 365 天聚合 < 100ms」。
//
// 和搜索那条压测一样：**这不是在测真机多久出结果**（这里是内存库 + 开发机，
// 真机要慢一截）。它抓的是量级错误——比如每天一次查询（365 次往返）、
// 或者热力图按格子去库里问一次（365 次）、或者聚合里写成 O(n²) 的嵌套。
// 这类写法在这台机器上就会从几十毫秒跳到几秒。
//
// 拆成两段量：**读库**（drift 的活）和**聚合**（`lib/core/focus/focus_stats.dart`
// 的活）。验收要守的是后者，所以阈值卡在它身上；读库那条给宽一点，只用来
// 抓「多了个数量级」。

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/focus_session_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FocusSessionRepository sessions;

  /// 窗口与统计页完全一致：今天往前数 365 天（含今天）。
  late int from;
  late int to;
  late DateTime now;

  setUp(() async {
    db = createTestDatabase();
    await db.ensureInitialized();
    sessions = FocusSessionRepository(db);

    now = DateTime.now();
    final DateTime today = fromUtcMillis(dayOnlyMillis(now));
    to = dayOnlyMillis(today);
    from = dayOnlyMillis(
      DateTime(
        today.year,
        today.month,
        today.day - (kFocusStatsWindowDays - 1),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 每天三段（上午 / 下午 / 晚上），一年 365 天共 1095 段。
  ///
  /// 走仓储而不是直接插表：压测要量的正是这条真实路径。
  /// 整批包在一个事务里，否则 2190 次单条写入本身就要跑很久。
  Future<int> seedYear() async {
    int expected = 0;
    await db.transaction(() async {
      final DateTime base = fromUtcMillis(from);
      for (int offset = 0; offset < kFocusStatsWindowDays; offset++) {
        final DateTime day = DateTime(base.year, base.month, base.day + offset);
        final List<int> minutes = <int>[25, 50, 90];
        for (int i = 0; i < minutes.length; i++) {
          final DateTime startedAt = DateTime(
            day.year,
            day.month,
            day.day,
            9 + i * 5,
          );
          final Duration duration = Duration(minutes: minutes[i]);
          final String id = await sessions.start(
            at: startedAt,
            logicalDate: dayOnlyMillis(startedAt),
            plan: duration,
          );
          await sessions.finish(id, at: startedAt.add(duration));
          expected += duration.inSeconds;
        }
      }
    });
    return expected;
  }

  test('一年 365 天全读进来之后，聚合的数字对得上', () async {
    final int expected = await seedYear();

    final List<FocusSlice> slices = await sessions.slicesBetween(
      from: from,
      to: to,
      now: now,
    );
    final FocusStats stats = FocusStats.from(
      slices: slices,
      from: from,
      to: to,
    );

    expect(stats.sessionCount, 365 * 3);
    expect(stats.total, expected);
    // 窗口里每一天都有记录，所以补齐之后一格不少。
    expect(stats.days, hasLength(kFocusStatsWindowDays));
    expect(stats.daysWithData, kFocusStatsWindowDays);
    expect(stats.currentStreak(to), kFocusStatsWindowDays);
    expect(stats.longestStreak(), kFocusStatsWindowDays);
    // 小时桶是**整个窗口**的同一个钟点，不是「每天 9 点那一段」——
    // 一年里每天 9 点那 25 分钟会累加到同一格里。
    expect(stats.hours[9], 25 * 60 * kFocusStatsWindowDays);
    expect(peakHour(stats.hours), 19);
  });

  test('一年 365 天的聚合在 100ms 内完成', () async {
    await seedYear();

    final Stopwatch read = Stopwatch()..start();
    final List<FocusSlice> slices = await sessions.slicesBetween(
      from: from,
      to: to,
      now: now,
    );
    read.stop();

    // 先空跑一次：第一次要把分支和字符串路径都编译出来，
    // 那不是用户每次翻统计页都要付的代价。
    FocusStats.from(slices: slices, from: from, to: to);

    int worst = 0;
    for (int i = 0; i < 3; i++) {
      final Stopwatch sw = Stopwatch()..start();
      final FocusStats stats = FocusStats.from(
        slices: slices,
        from: from,
        to: to,
      );
      sw.stop();
      // 顺手把它按住：不然 D8 可能把没被用到的计算整个优化掉。
      expect(stats.days, hasLength(kFocusStatsWindowDays));
      if (sw.elapsedMilliseconds > worst) worst = sw.elapsedMilliseconds;
    }

    debugPrint(
      '[统计压测] 1095 段 · 读库 ${read.elapsedMilliseconds}ms · '
      '聚合 ${worst}ms（三次里最慢的一次）',
    );

    expect(worst, lessThan(100));
    // 读库这条给得宽：它抓的是「365 次查询」这种量级错误，不是抖动。
    expect(read.elapsedMilliseconds, lessThan(1000));
  });
}
