import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/recurrence/recurrence_rule.dart';
import 'package:now_todo/core/recurrence/recurrence_text.dart';

/// 规则那句人话。
///
/// 这句话是用户在编辑页唯一能读到的确认信息，所以它得把规则本身的坑一起
/// 说出来：选了 31 日要提短月，选了 2 月 29 日要提平年。测试就是用来钉住
/// 这些提示不会哪天被顺手删掉。
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day, 9);

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

  test('每天与「每 N 天」', () {
    expect(describeRecurrence(rule(startsOn: d(2026, 1, 1))), '每天');
    expect(
      describeRecurrence(rule(startsOn: d(2026, 1, 1), interval: 3)),
      '每 3 天',
    );
    expect(
      describeRecurrence(rule(startsOn: d(2026, 1, 1), interval: 0)),
      '每天',
    );
  });

  group('每周', () {
    test('没指定星期几就按锚点那一天说', () {
      // 2026-01-07 是周三。
      expect(
        describeRecurrence(
          rule(startsOn: d(2026, 1, 7), frequency: RecurrenceFrequency.weekly),
        ),
        '每周三',
      );
    });

    test('指定了就用星期几本身，升序', () {
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{3, 1},
          ),
        ),
        '每周一、三',
      );
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 4),
            frequency: RecurrenceFrequency.weekly,
            byWeekday: <int>{7},
          ),
        ),
        '每周日',
      );
    });

    test('隔周会把周数说出来', () {
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 5),
            frequency: RecurrenceFrequency.weekly,
            interval: 2,
            byWeekday: <int>{DateTime.monday},
          ),
        ),
        '每 2 周的周一',
      );
    });
  });

  group('每月', () {
    test('按锚点号数', () {
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 15),
            frequency: RecurrenceFrequency.monthly,
          ),
        ),
        '每月 15 日',
      );
    });

    test('29 日以后要把短月的处理说出来', () {
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 31),
            frequency: RecurrenceFrequency.monthly,
          ),
        ),
        '每月 31 日（短月落在月末）',
      );
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 28),
            frequency: RecurrenceFrequency.monthly,
          ),
        ),
        '每月 28 日',
        reason: '28 日在任何月份都存在，不需要提示',
      );
    });

    test('多天与隔月', () {
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 10),
            frequency: RecurrenceFrequency.monthly,
            byMonthDay: <int>{15, 1},
          ),
        ),
        '每月 1、15 日',
      );
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 1, 31),
            frequency: RecurrenceFrequency.monthly,
            interval: 2,
          ),
        ),
        '每 2 个月 31 日（短月落在月末）',
      );
    });
  });

  group('每年', () {
    test('按锚点的月日', () {
      expect(
        describeRecurrence(
          rule(startsOn: d(2026, 6, 1), frequency: RecurrenceFrequency.yearly),
        ),
        '每年 6 月 1 日',
      );
      expect(
        describeRecurrence(
          rule(
            startsOn: d(2026, 6, 1),
            frequency: RecurrenceFrequency.yearly,
            interval: 3,
          ),
        ),
        '每 3 年的 6 月 1 日',
      );
    });

    test('2 月 29 日要说清平年怎么办', () {
      expect(
        describeRecurrence(
          rule(startsOn: d(2028, 2, 29), frequency: RecurrenceFrequency.yearly),
        ),
        '每年 2 月 29 日（平年落在 2 月 28 日）',
      );
    });
  });

  group('结束条件接在后面', () {
    test('按日期', () {
      expect(
        describeRecurrence(
          rule(startsOn: d(2026, 3, 1), endDate: d(2026, 12, 31)),
        ),
        '每天，到 2026-12-31 结束',
      );
    });

    test('按次数', () {
      expect(
        describeRecurrence(rule(startsOn: d(2026, 3, 1), endCount: 10)),
        '每天，共 10 次',
      );
    });

    test('两个都有时都说', () {
      expect(
        describeRecurrence(
          rule(startsOn: d(2026, 3, 1), endDate: d(2026, 12, 31), endCount: 10),
        ),
        '每天，到 2026-12-31 结束，共 10 次',
      );
    });
  });

  group('下一次的日期', () {
    test('按规则算出来', () {
      expect(
        nextOccurrenceText(rule(startsOn: d(2026, 1, 1)), now: d(2026, 3, 7)),
        '2026-03-08',
      );
    });

    test('系列已经结束就没有下一次', () {
      expect(
        nextOccurrenceText(
          rule(startsOn: d(2026, 1, 1), endDate: d(2026, 1, 3)),
          now: d(2026, 3, 7),
        ),
        isNull,
      );
    });

    test('月号补零，别出现 2026-3-8', () {
      expect(
        nextOccurrenceText(rule(startsOn: d(2026, 1, 1)), now: d(2026, 3, 7)),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });
  });
}
