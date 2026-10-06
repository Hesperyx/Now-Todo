// 统计口径的用例。
//
// 这里咬得比较细的地方是**边界**：午夜模式的 03:59:59 / 04:00:00、跨小时
// 的切分、连续天数在「今天还没开始专注」时的算不算断。这些都是口径问题，
// 口径错了整张图都是错的，而且不会有任何报错。

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/utils/time.dart';

void main() {
  int at(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) => DateTime(year, month, day, hour, minute, second).utcMillis;

  int day(int year, int month, int day) =>
      dayOnlyMillis(DateTime(year, month, day));

  FocusSlice slice({
    required int logicalDate,
    required int startedAt,
    required int seconds,
  }) {
    return FocusSlice(
      logicalDate: logicalDate,
      startedAt: startedAt,
      seconds: seconds,
    );
  }

  group('logicalDateFor · 关掉午夜模式', () {
    test('凌晨三点开始的算当天', () {
      expect(
        logicalDateFor(at(2026, 10, 7, 3), midnightMode: false),
        day(2026, 10, 7),
      );
    });

    test('午夜过后一分钟开始的算当天', () {
      expect(
        logicalDateFor(at(2026, 10, 7, 0, 1), midnightMode: false),
        day(2026, 10, 7),
      );
    });

    test('边界小时给 0 等价于关闭', () {
      expect(
        logicalDateFor(
          at(2026, 10, 7, 2),
          midnightMode: false,
          midnightEndHour: 0,
        ),
        day(2026, 10, 7),
      );
      expect(
        logicalDateFor(
          at(2026, 10, 7, 2),
          midnightMode: true,
          midnightEndHour: 0,
        ),
        day(2026, 10, 7),
      );
    });
  });

  group('logicalDateFor · 午夜模式（边界 4 点）', () {
    test('03:59:59 开始算前一天', () {
      expect(
        logicalDateFor(
          at(2026, 10, 7, 3, 59, 59),
          midnightMode: true,
          midnightEndHour: 4,
        ),
        day(2026, 10, 6),
      );
    });

    test('04:00:00 开始算当天', () {
      expect(
        logicalDateFor(
          at(2026, 10, 7, 4),
          midnightMode: true,
          midnightEndHour: 4,
        ),
        day(2026, 10, 7),
      );
    });

    test('午夜过后一分钟算前一天', () {
      expect(
        logicalDateFor(at(2026, 10, 7, 0, 1), midnightMode: true),
        day(2026, 10, 6),
      );
    });

    test('白天开始的算当天', () {
      expect(
        logicalDateFor(at(2026, 10, 7, 12), midnightMode: true),
        day(2026, 10, 7),
      );
    });

    test('跨月：11 月 1 日凌晨算 10 月 31 日', () {
      expect(
        logicalDateFor(at(2026, 11, 1, 2), midnightMode: true),
        day(2026, 10, 31),
      );
    });

    test('跨年：1 月 1 日凌晨算上一年最后一天', () {
      expect(
        logicalDateFor(at(2027, 1, 1, 1), midnightMode: true),
        day(2026, 12, 31),
      );
    });

    test('边界小时可以改：6 点时 05:30 算前一天', () {
      expect(
        logicalDateFor(
          at(2026, 10, 7, 5, 30),
          midnightMode: true,
          midnightEndHour: 6,
        ),
        day(2026, 10, 6),
      );
      expect(
        logicalDateFor(
          at(2026, 10, 7, 6),
          midnightMode: true,
          midnightEndHour: 6,
        ),
        day(2026, 10, 7),
      );
    });
  });

  group('previousLocalDay', () {
    test('跨月回退', () {
      expect(previousLocalDay(day(2026, 11, 1)), day(2026, 10, 31));
    });

    test('跨年回退', () {
      expect(previousLocalDay(day(2027, 1, 1)), day(2026, 12, 31));
    });

    test('二月末尾回退', () {
      expect(previousLocalDay(day(2028, 3, 1)), day(2028, 2, 29));
    });
  });

  group('secondsByDay', () {
    test('同一天的多条记录相加', () {
      final Map<int, int> byDay = secondsByDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 6),
          startedAt: at(2026, 10, 6, 9),
          seconds: 1500,
        ),
        slice(
          logicalDate: day(2026, 10, 6),
          startedAt: at(2026, 10, 6, 11),
          seconds: 600,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9),
          seconds: 900,
        ),
      ]);

      expect(byDay[day(2026, 10, 6)], 2100);
      expect(byDay[day(2026, 10, 7)], 900);
      expect(byDay, hasLength(2));
    });

    test('零秒与负秒的会话不占格子', () {
      final Map<int, int> byDay = secondsByDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 6),
          startedAt: at(2026, 10, 6, 9),
          seconds: 0,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9),
          seconds: -5,
        ),
      ]);

      expect(byDay, isEmpty);
    });

    test('空输入给空结果', () {
      expect(secondsByDay(const <FocusSlice>[]), isEmpty);
    });
  });

  group('secondsByHourOfDay', () {
    test('不跨小时时整块落在开始那一小时', () {
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9, 5),
          seconds: 600,
        ),
      ]);

      expect(byHour, <int, int>{9: 600});
    });

    test('跨小时时被切开，分别落进真正占据的两个小时', () {
      // 09:50 开始 20 分钟 → 09 点 10 分钟，10 点 10 分钟。
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9, 50),
          seconds: 1200,
        ),
      ]);

      expect(byHour, <int, int>{9: 600, 10: 600});
    });

    test('跨午夜时绕回 0 点', () {
      // 23:30 开始 90 分钟 → 23 点 30 分钟，次日 0 点 60 分钟。
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 23, 30),
          seconds: 5400,
        ),
      ]);

      expect(byHour, <int, int>{23: 1800, 0: 3600});
    });

    test('跨过好几个小时也能铺满中间那些格子', () {
      // 13:00 开始 3 小时 → 13/14/15 各 3600 秒。
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 13),
          seconds: 10800,
        ),
      ]);

      expect(byHour, <int, int>{13: 3600, 14: 3600, 15: 3600});
    });

    test('多条记录在同一小时内累加', () {
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9, 5),
          seconds: 300,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9, 40),
          seconds: 600,
        ),
      ]);

      expect(byHour, <int, int>{9: 900});
    });

    test('切分之后总秒数不变', () {
      final List<FocusSlice> slices = <FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9, 50),
          seconds: 1200,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 23, 30),
          seconds: 5400,
        ),
      ];
      final int summed = secondsByHourOfDay(
        slices,
      ).values.reduce((int a, int b) => a + b);

      expect(summed, totalSeconds(slices));
    });

    test('零秒与负秒不产生键', () {
      final Map<int, int> byHour = secondsByHourOfDay(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9),
          seconds: 0,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 9),
          seconds: -1,
        ),
      ]);

      expect(byHour, isEmpty);
    });
  });

  group('totalSeconds', () {
    test('只加正数', () {
      expect(
        totalSeconds(<FocusSlice>[
          slice(
            logicalDate: day(2026, 10, 7),
            startedAt: at(2026, 10, 7, 9),
            seconds: 900,
          ),
          slice(
            logicalDate: day(2026, 10, 7),
            startedAt: at(2026, 10, 7, 10),
            seconds: 0,
          ),
          slice(
            logicalDate: day(2026, 10, 7),
            startedAt: at(2026, 10, 7, 11),
            seconds: -60,
          ),
        ]),
        900,
      );
    });

    test('空输入给 0', () {
      expect(totalSeconds(const <FocusSlice>[]), 0);
    });
  });

  group('currentStreakDays', () {
    test('今天有记录，往前数连续天', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 10, 7): 900,
        day(2026, 10, 6): 900,
        day(2026, 10, 5): 900,
        day(2026, 10, 3): 900,
      };

      expect(currentStreakDays(byDay, today: day(2026, 10, 7)), 3);
    });

    test('今天还没开始专注时，不算断', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 10, 6): 900,
        day(2026, 10, 5): 900,
      };

      expect(currentStreakDays(byDay, today: day(2026, 10, 7)), 2);
    });

    test('今天和昨天都没有，连续天数为 0', () {
      final Map<int, int> byDay = <int, int>{day(2026, 10, 5): 900};

      expect(currentStreakDays(byDay, today: day(2026, 10, 7)), 0);
    });

    test('完全没有记录是 0', () {
      expect(currentStreakDays(const <int, int>{}, today: day(2026, 10, 7)), 0);
    });

    test('零秒的记录不算数', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 10, 7): 900,
        day(2026, 10, 6): 0,
        day(2026, 10, 5): 900,
      };

      expect(currentStreakDays(byDay, today: day(2026, 10, 7)), 1);
    });

    test('跨月连续', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 11, 1): 900,
        day(2026, 10, 31): 900,
        day(2026, 10, 30): 900,
      };

      expect(currentStreakDays(byDay, today: day(2026, 11, 1)), 3);
    });
  });

  group('longestStreakDays', () {
    test('取历史上最长的一段', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 10, 1): 900,
        day(2026, 10, 2): 900,
        // 断一天
        day(2026, 10, 4): 900,
        day(2026, 10, 5): 900,
        day(2026, 10, 6): 900,
        day(2026, 10, 7): 900,
      };

      expect(longestStreakDays(byDay), 4);
    });

    test('只有一天时是 1', () {
      expect(longestStreakDays(<int, int>{day(2026, 10, 7): 900}), 1);
    });

    test('没有记录是 0', () {
      expect(longestStreakDays(const <int, int>{}), 0);
    });

    test('零秒的记录不参与连段', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 10, 5): 900,
        day(2026, 10, 6): 0,
        day(2026, 10, 7): 900,
      };

      expect(longestStreakDays(byDay), 1);
    });

    test('跨年连续也算一段', () {
      final Map<int, int> byDay = <int, int>{
        day(2026, 12, 31): 900,
        day(2027, 1, 1): 900,
      };

      expect(longestStreakDays(byDay), 2);
    });
  });

  group('summarizeDays · 有记录和有时长是两件事', () {
    test('同一天的多条合并，条数也记下来', () {
      final List<FocusDaySummary> days = summarizeDays(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7),
          seconds: 900,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7, 1),
          seconds: 600,
        ),
      ]);

      expect(days.length, 1);
      expect(days.single.seconds, 1500);
      expect(days.single.sessions, 2);
    });

    test('只有 0 秒记录的那天留着，但不算有时长', () {
      final List<FocusDaySummary> days = summarizeDays(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7),
          seconds: 0,
        ),
      ]);

      expect(days.single.seconds, 0);
      expect(days.single.sessions, 1);
      expect(days.single.isEmpty, isFalse);
      expect(days.single.hasTime, isFalse);
    });

    test('完全没有记录的那天不会出现', () {
      final List<FocusDaySummary> days = summarizeDays(const <FocusSlice>[]);

      expect(days, isEmpty);
    });

    test('按日升序，与传入顺序无关', () {
      final List<FocusDaySummary> days = summarizeDays(<FocusSlice>[
        slice(
          logicalDate: day(2026, 10, 9),
          startedAt: at(2026, 10, 9),
          seconds: 60,
        ),
        slice(
          logicalDate: day(2026, 10, 7),
          startedAt: at(2026, 10, 7),
          seconds: 60,
        ),
        slice(
          logicalDate: day(2026, 10, 8),
          startedAt: at(2026, 10, 8),
          seconds: 60,
        ),
      ]);

      expect(days.map((FocusDaySummary d) => d.day).toList(), <int>[
        day(2026, 10, 7),
        day(2026, 10, 8),
        day(2026, 10, 9),
      ]);
    });
  });

  group('fillDayRange · 把缺的日期补成空白', () {
    test('两端都含，中间缺的日期补 0', () {
      final List<FocusDaySummary> filled = fillDayRange(
        summarizeDays(<FocusSlice>[
          slice(
            logicalDate: day(2026, 10, 7),
            startedAt: at(2026, 10, 7),
            seconds: 900,
          ),
        ]),
        from: day(2026, 10, 6),
        to: day(2026, 10, 9),
      );

      expect(filled.length, 4);
      expect(filled.map((FocusDaySummary d) => d.day).toList(), <int>[
        day(2026, 10, 6),
        day(2026, 10, 7),
        day(2026, 10, 8),
        day(2026, 10, 9),
      ]);
      expect(filled[0].isEmpty, isTrue);
      expect(filled[1].seconds, 900);
      expect(filled[2].isEmpty, isTrue);
      expect(filled[3].isEmpty, isTrue);
    });

    test('跨月跨年都按日历走', () {
      final List<FocusDaySummary> filled = fillDayRange(
        const <FocusDaySummary>[],
        from: day(2026, 12, 30),
        to: day(2027, 1, 2),
      );

      expect(filled.length, 4);
      expect(filled.last.day, day(2027, 1, 2));
    });

    test('起始与结束是同一天时只给一格', () {
      final List<FocusDaySummary> filled = fillDayRange(
        const <FocusDaySummary>[],
        from: day(2026, 10, 7),
        to: day(2026, 10, 7),
      );

      expect(filled.length, 1);
    });

    test('闰年二月给 29 天', () {
      final List<FocusDaySummary> filled = fillDayRange(
        const <FocusDaySummary>[],
        from: day(2028, 2, 1),
        to: day(2028, 2, 29),
      );

      expect(filled.length, 29);
      expect(filled.last.day, day(2028, 2, 29));
    });
  });

  group('weekStartOf 与 monthStartOf', () {
    test('周三所在的那周从周一算起', () {
      // 2026-10-07 是周三。
      expect(weekStartOf(day(2026, 10, 7)), day(2026, 10, 5));
    });

    test('周一自己就是起点', () {
      expect(weekStartOf(day(2026, 10, 5)), day(2026, 10, 5));
    });

    test('周日算本周的最后一天，不算下周', () {
      expect(weekStartOf(day(2026, 10, 11)), day(2026, 10, 5));
    });

    test('跨月的那一周仍从上周一算起', () {
      // 2026-11-01 是周日。
      expect(weekStartOf(day(2026, 11, 1)), day(2026, 10, 26));
    });

    test('月起点是 1 号', () {
      expect(monthStartOf(day(2026, 10, 7)), day(2026, 10, 1));
    });
  });

  group('groupBySpan · 日周月的合计', () {
    List<FocusDaySummary> sample() => summarizeDays(<FocusSlice>[
      // 10-05 周一 15 分钟，10-06 周二 30 分钟，10-07 周三 0 秒（有记录）。
      slice(
        logicalDate: day(2026, 10, 5),
        startedAt: at(2026, 10, 5),
        seconds: 900,
      ),
      slice(
        logicalDate: day(2026, 10, 6),
        startedAt: at(2026, 10, 6),
        seconds: 1800,
      ),
      slice(
        logicalDate: day(2026, 10, 7),
        startedAt: at(2026, 10, 7),
        seconds: 0,
      ),
      // 10-13 周二（下一周）。
      slice(
        logicalDate: day(2026, 10, 13),
        startedAt: at(2026, 10, 13),
        seconds: 600,
      ),
    ]);

    test('按日给每天的合计', () {
      final List<FocusPeriodTotal> perDay = groupBySpan(
        sample(),
        FocusSpan.day,
      );

      expect(perDay.length, 4);
      expect(perDay.first.start, day(2026, 10, 5));
      expect(perDay.first.seconds, 900);
      expect(perDay.first.daysWithData, 1);
    });

    test('按周把同一周合在一起，起点是周一', () {
      final List<FocusPeriodTotal> week = groupBySpan(sample(), FocusSpan.week);

      expect(week.length, 2);
      expect(week.first.start, day(2026, 10, 5));
      expect(week.first.seconds, 2700);
      expect(week.first.sessions, 3);
      // 这一周里只有两天真的有时长（10-07 那条是 0 秒）。
      expect(week.first.daysWithData, 2);
      expect(week.last.start, day(2026, 10, 12));
      expect(week.last.seconds, 600);
    });

    test('按月把同一个月合在一起', () {
      final List<FocusPeriodTotal> month = groupBySpan(
        sample(),
        FocusSpan.month,
      );

      expect(month.length, 1);
      expect(month.single.start, day(2026, 10, 1));
      expect(month.single.seconds, 3300);
      expect(month.single.daysWithData, 3);
    });

    test('没有记录时不产出空段', () {
      expect(groupBySpan(const <FocusDaySummary>[], FocusSpan.week), isEmpty);
    });

    test('只有 0 秒记录的一天仍然占一段，但 daysWithData 是 0', () {
      final List<FocusPeriodTotal> week = groupBySpan(
        summarizeDays(<FocusSlice>[
          slice(
            logicalDate: day(2026, 10, 7),
            startedAt: at(2026, 10, 7),
            seconds: 0,
          ),
        ]),
        FocusSpan.week,
      );

      expect(week.single.sessions, 1);
      expect(week.single.daysWithData, 0);
    });
  });

  group('heatOf · 五个档位', () {
    FocusDaySummary dayOf({required int seconds, required int sessions}) =>
        FocusDaySummary(
          day: day(2026, 10, 7),
          seconds: seconds,
          sessions: sessions,
        );

    test('没有记录是 none', () {
      expect(heatOf(dayOf(seconds: 0, sessions: 0)), FocusHeat.none);
    });

    test('有记录但一秒没计时是 zero', () {
      expect(heatOf(dayOf(seconds: 0, sessions: 1)), FocusHeat.zero);
    });

    test('15 分钟以下是 light', () {
      expect(heatOf(dayOf(seconds: 899, sessions: 1)), FocusHeat.light);
    });

    test('刚好 15 分钟进 medium', () {
      expect(heatOf(dayOf(seconds: 900, sessions: 1)), FocusHeat.medium);
    });

    test('刚好一小时进 heavy', () {
      expect(heatOf(dayOf(seconds: 3600, sessions: 1)), FocusHeat.heavy);
    });

    test('负秒数不会算成有时长', () {
      expect(heatOf(dayOf(seconds: -5, sessions: 1)), FocusHeat.zero);
    });
  });

  group('peakHour · 最坐得住的一小时', () {
    test('取秒数最多的那一小时', () {
      expect(peakHour(const <int, int>{9: 600, 10: 1800, 11: 300}), 10);
    });

    test('并列时取更早的那个', () {
      expect(peakHour(const <int, int>{14: 600, 9: 600}), 9);
    });

    test('没有数据返回 null', () {
      expect(peakHour(const <int, int>{}), isNull);
    });

    test('全是 0 也返回 null，不编一个 0 点出来', () {
      expect(peakHour(const <int, int>{9: 0, 10: 0}), isNull);
    });
  });
}
