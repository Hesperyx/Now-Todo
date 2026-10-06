import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';

/// 重复规则的日期计算。
///
/// 这一层的全部价值就是「算对日期」，所以用例全是具体的日期：跨月、月末、
/// 闰年、指定星期几、指定号数、结束条件。日期事实在写用例时逐个核对过，
/// 例如 2026-01-01 是周四、2028 年是闰年。
void main() {
  DateTime d(int year, int month, int day, [int hour = 9]) =>
      DateTime(year, month, day, hour);

  RecurrenceRule rule({
    required DateTime startsOn,
    RecurrenceFrequency frequency = RecurrenceFrequency.daily,
    int interval = 1,
    Set<int> byWeekday = const <int>{},
    Set<int> byMonthDay = const <int>{},
    DateTime? endDate,
    int? endCount,
  }) => RecurrenceRule(
    startsOn: startsOn,
    frequency: frequency,
    interval: interval,
    byWeekday: byWeekday,
    byMonthDay: byMonthDay,
    endDate: endDate,
    endCount: endCount,
  );

  /// 从锚点开始连取 [count] 次。
  List<DateTime> take(RecurrenceRule r, int count, {DateTime? after}) {
    final List<DateTime> result = <DateTime>[];
    DateTime cursor = after ?? r.startsOn.subtract(const Duration(seconds: 1));
    for (int i = 0; i < count; i++) {
      final DateTime? next = occurrenceAfter(r, cursor);
      if (next == null) break;
      result.add(next);
      cursor = next;
    }
    return result;
  }

  group('firstOccurrence · 第 1 次落在哪天', () {
    test('每天就是锚点本身', () {
      expect(firstOccurrence(rule(startsOn: d(2026, 1, 1))), d(2026, 1, 1));
    });

    test('每周没指定星期几时，第 1 次是锚点', () {
      expect(
        firstOccurrence(
          rule(startsOn: d(2026, 1, 7), frequency: RecurrenceFrequency.weekly),
        ),
        d(2026, 1, 7),
      );
    });

    test('每周指定的那天晚于锚点，取同一周的那天', () {
      // 2026-01-07 是周三，周五是 01-09。
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 1, 7),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{5},
          ),
        ),
        d(2026, 1, 9),
      );
    });

    test('每周指定的那天早于锚点，跳到下一周', () {
      // 锚点是周三 01-07，周一已经过去了，第 1 次落在 01-12。
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 1, 7),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1},
          ),
        ),
        d(2026, 1, 12),
      );
    });

    test('每月没指定号数时，第 1 次是锚点', () {
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 1, 20),
            frequency: RecurrenceFrequency.monthly,
          ),
        ),
        d(2026, 1, 20),
      );
    });

    test('每月指定的号数还没到，就在当月', () {
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{15},
          ),
        ),
        d(2026, 1, 15),
      );
    });

    test('每月指定的号数已经过了，落到下个月', () {
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 1, 20),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{5},
          ),
        ),
        d(2026, 2, 5),
      );
    });

    test('每月指定的 31 号在 2 月落到月末，而不是跳过这个月', () {
      expect(
        firstOccurrence(
          rule(
            startsOn: d(2026, 2, 10),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{31},
          ),
        ),
        d(2026, 2, 28),
      );
    });

    test('每年就是锚点', () {
      expect(
        firstOccurrence(
          rule(startsOn: d(2026, 6, 1), frequency: RecurrenceFrequency.yearly),
        ),
        d(2026, 6, 1),
      );
    });

    test('结束日期早于开始日期时，第 1 次照样给得出来', () {
      // 界面要能把一条自相矛盾的规则原样显示出来，而不是抛异常。
      expect(
        firstOccurrence(
          rule(startsOn: d(2026, 6, 1), endDate: DateTime(2026, 1, 1)),
        ),
        d(2026, 6, 1),
      );
    });
  });

  group('每天 · 推进', () {
    test('连取 5 次就是连着 5 天', () {
      expect(take(rule(startsOn: d(2026, 1, 1)), 5), <DateTime>[
        d(2026, 1, 1),
        d(2026, 1, 2),
        d(2026, 1, 3),
        d(2026, 1, 4),
        d(2026, 1, 5),
      ]);
    });

    test('间隔 3 天', () {
      expect(take(rule(startsOn: d(2026, 1, 1), interval: 3), 4), <DateTime>[
        d(2026, 1, 1),
        d(2026, 1, 4),
        d(2026, 1, 7),
        d(2026, 1, 10),
      ]);
    });

    test('跨月不靠天数硬加，2 月只有 28 天也接得上', () {
      expect(take(rule(startsOn: d(2026, 1, 30), interval: 3), 4), <DateTime>[
        d(2026, 1, 30),
        d(2026, 2, 2),
        d(2026, 2, 5),
        d(2026, 2, 8),
      ]);
    });

    test('跨年', () {
      expect(take(rule(startsOn: d(2026, 12, 30)), 3), <DateTime>[
        d(2026, 12, 30),
        d(2026, 12, 31),
        d(2027, 1, 1),
      ]);
    });

    test('锚点带的时刻会被保留', () {
      final List<DateTime> days = take(rule(startsOn: d(2026, 1, 1, 9)), 3);
      expect(days[0].hour, 9);
      expect(days[1].hour, 9);
      expect(days[2].hour, 9);
    });
  });

  group('每周 · 星期几', () {
    test('没指定星期几时每 7 天一次', () {
      expect(
        take(
          rule(startsOn: d(2026, 1, 5), frequency: RecurrenceFrequency.weekly),
          3,
        ),
        <DateTime>[d(2026, 1, 5), d(2026, 1, 12), d(2026, 1, 19)],
      );
    });

    test('指定周一：每个周一', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1},
          ),
          3,
        ),
        <DateTime>[d(2026, 1, 5), d(2026, 1, 12), d(2026, 1, 19)],
      );
    });

    test('指定周一、三、五：一周内按顺序出现三次', () {
      // 2026-01-05 是周一。
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1, 3, 5},
          ),
          6,
        ),
        <DateTime>[
          d(2026, 1, 5),
          d(2026, 1, 7),
          d(2026, 1, 9),
          d(2026, 1, 12),
          d(2026, 1, 14),
          d(2026, 1, 16),
        ],
      );
    });

    test('间隔 2 周 + 指定周一：隔周的周一', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            interval: 2,
            byWeekday: <int>{1},
          ),
          4,
        ),
        <DateTime>[
          d(2026, 1, 5),
          d(2026, 1, 19),
          d(2026, 2, 2),
          d(2026, 2, 16),
        ],
      );
    });

    test('七个星期几全选就等于每天', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1, 2, 3, 4, 5, 6, 7},
          ),
          4,
        ),
        <DateTime>[d(2026, 1, 5), d(2026, 1, 6), d(2026, 1, 7), d(2026, 1, 8)],
      );
    });
  });

  group('每月 · 月末是重点', () {
    test('锚点在 31 号：短月落到月末，但下个月要回到 31 号', () {
      // 这是「始终从锚点推算」而不是「在上一次结果上加一个月」的原因：
      // 后者会在 2 月夹到 28 之后一路变成 28 号。
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 31),
            frequency: RecurrenceFrequency.monthly,
          ),
          4,
        ),
        <DateTime>[
          d(2026, 1, 31),
          d(2026, 2, 28),
          d(2026, 3, 31),
          d(2026, 4, 30),
        ],
      );
    });

    test('指定 31 号，从 1 月起', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 10),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{31},
          ),
          4,
        ),
        <DateTime>[
          d(2026, 1, 31),
          d(2026, 2, 28),
          d(2026, 3, 31),
          d(2026, 4, 30),
        ],
      );
    });

    test('指定 30 与 31 号，2 月只出现一次而不是两次', () {
      // 两个号数在 2 月都夹到 28 日。序列必须严格递增，否则「第一个晚于
      // X 的候选」会数错。
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{30, 31},
          ),
          5,
        ),
        <DateTime>[
          d(2026, 1, 30),
          d(2026, 1, 31),
          d(2026, 2, 28),
          d(2026, 3, 30),
          d(2026, 3, 31),
        ],
      );
    });

    test('指定 1 号与 15 号：每月两次', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{1, 15},
          ),
          4,
        ),
        <DateTime>[
          d(2026, 1, 1),
          d(2026, 1, 15),
          d(2026, 2, 1),
          d(2026, 2, 15),
        ],
      );
    });

    test('间隔 2 个月的月末：1 月 31 → 3 月 31 → 5 月 31', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 31),
            frequency: RecurrenceFrequency.monthly,
            interval: 2,
          ),
          3,
        ),
        <DateTime>[d(2026, 1, 31), d(2026, 3, 31), d(2026, 5, 31)],
      );
    });

    test('29 号在闰年 2 月就是 29 号', () {
      // 2028 是闰年。
      expect(
        take(
          rule(
            startsOn: d(2028, 1, 29),
            frequency: RecurrenceFrequency.monthly,
          ),
          3,
        ),
        <DateTime>[d(2028, 1, 29), d(2028, 2, 29), d(2028, 3, 29)],
      );
    });

    test('29 号在平年 2 月落到 28，3 月回到 29', () {
      expect(
        take(
          rule(
            startsOn: d(2027, 1, 29),
            frequency: RecurrenceFrequency.monthly,
          ),
          3,
        ),
        <DateTime>[d(2027, 1, 29), d(2027, 2, 28), d(2027, 3, 29)],
      );
    });

    test('指定的号数在当月已经过去时会落到下个月', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 20),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{5},
          ),
          3,
        ),
        <DateTime>[d(2026, 2, 5), d(2026, 3, 5), d(2026, 4, 5)],
      );
    });
  });

  group('每年', () {
    test('每年同一天', () {
      expect(
        take(
          rule(startsOn: d(2026, 6, 1), frequency: RecurrenceFrequency.yearly),
          3,
        ),
        <DateTime>[d(2026, 6, 1), d(2027, 6, 1), d(2028, 6, 1)],
      );
    });

    test('2 月 29 日的锚点：平年落到 2 月 28，闰年回到 29', () {
      expect(
        take(
          rule(startsOn: d(2028, 2, 29), frequency: RecurrenceFrequency.yearly),
          5,
        ),
        <DateTime>[
          d(2028, 2, 29),
          d(2029, 2, 28),
          d(2030, 2, 28),
          d(2031, 2, 28),
          d(2032, 2, 29),
        ],
      );
    });

    test('间隔 3 年', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 6, 1),
            frequency: RecurrenceFrequency.yearly,
            interval: 3,
          ),
          3,
        ),
        <DateTime>[d(2026, 6, 1), d(2029, 6, 1), d(2032, 6, 1)],
      );
    });
  });

  group('结束条件', () {
    test('结束日期当天照常出现，第二天起没有下一次', () {
      final RecurrenceRule r = rule(
        startsOn: d(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );
      expect(take(r, 5), <DateTime>[
        d(2026, 1, 1),
        d(2026, 1, 2),
        d(2026, 1, 3),
      ]);
      expect(occurrenceAfter(r, d(2026, 1, 3)), isNull);
    });

    test('带时刻的结束日期按日历日比较，不看时刻', () {
      final RecurrenceRule r = rule(
        startsOn: d(2026, 1, 1, 9),
        endDate: DateTime(2026, 1, 3, 23, 59),
      );
      expect(occurrenceAfter(r, d(2026, 1, 2)), d(2026, 1, 3, 9));
      expect(occurrenceAfter(r, d(2026, 1, 3, 9)), isNull);
    });

    test('日期序列只看结束日期，次数由「系列有几条任务」判定', () {
      // `occurrenceAfter` 不知道这个系列已经生成了几条，所以它不判次数——
      // 判次数的活只在 nextAfterCompletion 里，那里的 seriesCount 来自
      // `tasks.recurrence_rule_id` 的行数。一个规则只有一处权威。
      final RecurrenceRule r = rule(startsOn: d(2026, 1, 1), endCount: 3);
      expect(take(r, 5), hasLength(5));
      expect(
        nextAfterCompletion(
          rule: r,
          instanceDate: d(2026, 1, 3),
          notBefore: d(2026, 1, 3),
          seriesCount: 3,
        ),
        isNull,
      );
    });

    test('只重复 1 次时，第 1 次完成之后就没有下一条', () {
      final RecurrenceRule r = rule(startsOn: d(2026, 1, 1), endCount: 1);
      expect(
        nextAfterCompletion(
          rule: r,
          instanceDate: d(2026, 1, 1),
          notBefore: d(2026, 1, 1),
          seriesCount: 1,
        ),
        isNull,
      );
    });

    test('结束日期比次数先到，日期序列按日期停', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 1),
            endDate: DateTime(2026, 1, 2),
            endCount: 10,
          ),
          5,
        ),
        <DateTime>[d(2026, 1, 1), d(2026, 1, 2)],
      );
    });

    test('次数比结束日期先到，次数这一边也会拦住下一条', () {
      final RecurrenceRule r = rule(
        startsOn: d(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        endCount: 2,
      );
      expect(
        nextAfterCompletion(
          rule: r,
          instanceDate: d(2026, 1, 2),
          notBefore: d(2026, 1, 2),
          seriesCount: 2,
        ),
        isNull,
      );
    });
  });

  group('完成后推下一条', () {
    DateTime? next(
      RecurrenceRule r, {
      required DateTime instance,
      required DateTime notBefore,
      int seriesCount = 1,
    }) => nextAfterCompletion(
      rule: r,
      instanceDate: instance,
      notBefore: notBefore,
      seriesCount: seriesCount,
    );

    test('每天：完成今天的，排明天的', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1)),
          instance: d(2026, 1, 5),
          notBefore: d(2026, 1, 5),
        ),
        d(2026, 1, 6),
      );
    });

    test('每周：完成本周一，排下周一', () {
      expect(
        next(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1},
          ),
          instance: d(2026, 1, 5),
          notBefore: d(2026, 1, 5),
        ),
        d(2026, 1, 12),
      );
    });

    test('每月 31 号：完成 1 月 31 排 2 月 28', () {
      expect(
        next(
          rule(
            startsOn: d(2026, 1, 31),
            frequency: RecurrenceFrequency.monthly,
          ),
          instance: d(2026, 1, 31),
          notBefore: d(2026, 1, 31),
        ),
        d(2026, 2, 28),
      );
    });

    test('拖了很久才完成：跳过所有已经过去的日子', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1)),
          instance: d(2026, 1, 1),
          notBefore: d(2026, 1, 10),
        ),
        d(2026, 1, 10),
      );
    });

    test('刚好等于最早允许的时刻时保留，不往后跳', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1)),
          instance: d(2026, 1, 1),
          notBefore: d(2026, 1, 2),
        ),
        d(2026, 1, 2),
      );
    });

    test('系列次数用完了就没有下一条', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1), endCount: 3),
          instance: d(2026, 1, 3),
          notBefore: d(2026, 1, 3),
          seriesCount: 3,
        ),
        isNull,
      );
    });

    test('次数还没用完就继续', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1), endCount: 3),
          instance: d(2026, 1, 2),
          notBefore: d(2026, 1, 2),
          seriesCount: 2,
        ),
        d(2026, 1, 3),
      );
    });

    test('被单独挪过的实例会被吸回原来的节奏', () {
      // 这是「仅此一次」的核心：这一条从周一挪到了周三完成，系列仍然是
      // 每周一，下一条是 01-19 而不是 01-21。
      expect(
        next(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1},
          ),
          instance: d(2026, 1, 14),
          notBefore: d(2026, 1, 14),
        ),
        d(2026, 1, 19),
      );
    });

    test('实例日期早于锚点（脏数据）时从第 1 次之后接', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 10)),
          instance: d(2026, 1, 1),
          notBefore: d(2026, 1, 1),
        ),
        d(2026, 1, 11),
      );
    });

    test('结束日期拦住了就没有下一条', () {
      expect(
        next(
          rule(startsOn: d(2026, 1, 1), endDate: DateTime(2026, 1, 5)),
          instance: d(2026, 1, 5),
          notBefore: d(2026, 1, 5),
        ),
        isNull,
      );
    });
  });

  group('occurrenceOnOrBefore · 把被挪过的日期吸回节奏', () {
    test('正好落在一次出现上，返回它本身', () {
      expect(
        occurrenceOnOrBefore(rule(startsOn: d(2026, 1, 1)), d(2026, 1, 5)),
        d(2026, 1, 5),
      );
    });

    test('落在两次之间，返回前一次', () {
      expect(
        occurrenceOnOrBefore(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{1},
          ),
          d(2026, 1, 14),
        ),
        d(2026, 1, 12),
      );
    });

    test('早于锚点，返回 null', () {
      expect(
        occurrenceOnOrBefore(rule(startsOn: d(2026, 1, 5)), d(2026, 1, 1)),
        isNull,
      );
    });
  });

  group('脏输入不能让它挂掉或算歪', () {
    test('间隔小于 1 当成 1', () {
      expect(take(rule(startsOn: d(2026, 1, 1), interval: 0), 3), <DateTime>[
        d(2026, 1, 1),
        d(2026, 1, 2),
        d(2026, 1, 3),
      ]);
      expect(take(rule(startsOn: d(2026, 1, 1), interval: -3), 3), <DateTime>[
        d(2026, 1, 1),
        d(2026, 1, 2),
        d(2026, 1, 3),
      ]);
    });

    test('越界的星期被丢掉，退化成「与锚点同一天」', () {
      // 2026-01-07 是周三。
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 7),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{0, 8, 99},
          ),
          3,
        ),
        <DateTime>[d(2026, 1, 7), d(2026, 1, 14), d(2026, 1, 21)],
      );
    });

    test('越界的号数被丢掉，退化成「与锚点同号」', () {
      expect(
        take(
          rule(
            startsOn: d(2026, 1, 10),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{0, 32},
          ),
          3,
        ),
        <DateTime>[d(2026, 1, 10), d(2026, 2, 10), d(2026, 3, 10)],
      );
    });

    test('1970 年的锚点也不会把线程卡住', () {
      // 真跑到搜索上界时返回 null，而不是一直转下去。
      expect(
        occurrenceAfter(rule(startsOn: DateTime(1970)), d(2026, 1, 1)),
        isNotNull,
      );
    });
  });

  test('任何规则的前 200 次都必须严格递增', () {
    final List<RecurrenceRule> samples = <RecurrenceRule>[
      rule(startsOn: d(2026, 1, 31), frequency: RecurrenceFrequency.monthly),
      rule(
        startsOn: d(2026, 1, 1),
        frequency: RecurrenceFrequency.monthly,
        byMonthDay: <int>{29, 30, 31},
      ),
      rule(
        startsOn: d(2026, 1, 5),
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        byWeekday: <int>{1, 3, 5},
      ),
      rule(startsOn: d(2028, 2, 29), frequency: RecurrenceFrequency.yearly),
      rule(startsOn: d(2026, 12, 28), interval: 5),
      rule(startsOn: d(2026, 3, 31), interval: 7),
    ];

    for (final RecurrenceRule r in samples) {
      final List<DateTime> occurrences = take(r, 200);
      expect(occurrences, hasLength(200), reason: '$r');
      for (int i = 1; i < occurrences.length; i++) {
        expect(
          occurrences[i].isAfter(occurrences[i - 1]),
          isTrue,
          reason: '$r 的第 $i 次没有晚于前一次',
        );
      }
    }
  });
}
