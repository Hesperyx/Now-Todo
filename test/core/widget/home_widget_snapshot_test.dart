import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/utils/time.dart';
import 'package:now_todo/core/widget/home_widget_snapshot.dart';

/// 某一天的本地零点毫秒。
int day(int year, int month, int dayOfMonth) =>
    dayOnlyMillis(DateTime(year, month, dayOfMonth));

/// 一段会话。[logicalDate] 默认就是开始那天。
FocusSlice slice(
  int year,
  int month,
  int dayOfMonth,
  int hour,
  int seconds, {
  int? logicalDate,
}) => FocusSlice(
  logicalDate: logicalDate ?? day(year, month, dayOfMonth),
  startedAt: DateTime(year, month, dayOfMonth, hour).utcMillis,
  seconds: seconds,
);

void main() {
  group('homeWidgetWindowStart · 窗口是最近七天', () {
    test('含今天在内，往回应数六天', () {
      expect(homeWidgetWindowStart(day(2026, 10, 7)), day(2026, 10, 1));
    });

    test('跨月', () {
      expect(homeWidgetWindowStart(day(2026, 11, 3)), day(2026, 10, 28));
    });

    test('跨年', () {
      expect(homeWidgetWindowStart(day(2027, 1, 2)), day(2026, 12, 27));
    });

    test('起点还是本地零点', () {
      // 平台侧拿它和记录里的 logicalDate 直接比大小，不是本地零点就永远对不上。
      final int start = homeWidgetWindowStart(day(2026, 10, 7));
      expect(dayOnlyMillis(fromUtcMillis(start)), start);
      expect(fromUtcMillis(start).hour, 0);
    });
  });

  group('HomeWidgetSnapshot · 卡片上那几行字', () {
    test('一条记录都没有：写「今天还没有专注」，七根柱子都是空档', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        const <FocusSlice>[],
        today: day(2026, 10, 7),
      );

      expect(snapshot.isEmpty, isTrue, reason: '七天空着才算空');
      expect(snapshot.headline, '今天还没有专注');
      expect(snapshot.caption, '去专注一段吧');
      expect(snapshot.levels, everyElement(FocusHeat.none.index));
      expect(snapshot.week, hasLength(kHomeWidgetDays));
    });

    test('今天来过但没计时：不算空，也不吹成有成绩', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[slice(2026, 10, 7, 9, 0)],
        today: day(2026, 10, 7),
      );

      expect(snapshot.isEmpty, isFalse, reason: '来过了，不是空的');
      expect(snapshot.headline, '今天来过，没计时');
      expect(snapshot.caption, '共 1 段');
      expect(snapshot.seconds, 0);
      expect(snapshot.levels.last, FocusHeat.zero.index);
      expect(
        snapshot.levels.take(kHomeWidgetDays - 1),
        everyElement(FocusHeat.none.index),
      );
    });

    test('今天 10 分钟：标题写时长，柱子在「少」那一档', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[slice(2026, 10, 7, 10, 10 * 60)],
        today: day(2026, 10, 7),
      );

      expect(snapshot.headline, '今天 10 分钟');
      expect(snapshot.caption, '共 1 段');
      expect(snapshot.seconds, 10 * 60);
      expect(snapshot.levels.last, FocusHeat.light.index);
    });

    test('今天 25 分钟：过了「少」那一档，但还不到一小时', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[slice(2026, 10, 7, 10, 25 * 60)],
        today: day(2026, 10, 7),
      );

      expect(snapshot.headline, '今天 25 分钟');
      expect(snapshot.levels.last, FocusHeat.medium.index);
    });

    test('柱子按四档阈值取色', () {
      // 档位边界与统计页共用一套（heatOf）：899/900 与 3599/3600 是两对界。
      final Map<int, int> expected = <int, int>{
        0: FocusHeat.zero.index,
        1: FocusHeat.light.index,
        899: FocusHeat.light.index,
        900: FocusHeat.medium.index,
        3599: FocusHeat.medium.index,
        3600: FocusHeat.heavy.index,
      };

      expected.forEach((int seconds, int level) {
        final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
          <FocusSlice>[slice(2026, 10, 7, 9, seconds)],
          today: day(2026, 10, 7),
        );
        expect(snapshot.levels.last, level, reason: '$seconds 秒应该是第 $level 档');
      });
    });

    test('前几天的成绩不冒充今天：标题只看今天', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[
          slice(2026, 10, 5, 9, 2 * 3600),
          slice(2026, 10, 6, 9, 3 * 3600),
        ],
        today: day(2026, 10, 7),
      );

      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.headline, '今天还没有专注');
      expect(snapshot.caption, '去专注一段吧');
      expect(snapshot.levels[4], FocusHeat.heavy.index, reason: '10-05');
      expect(snapshot.levels[5], FocusHeat.heavy.index, reason: '10-06');
      expect(snapshot.levels.last, FocusHeat.none.index, reason: '今天确实还没开始');
    });
  });

  group('HomeWidgetSnapshot.fromSlices · 窗口的边界', () {
    test('铺满连续七天，早于窗口的记录一根柱子都不算', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[
          slice(2026, 9, 30, 9, 3600), // 窗口起点（10-01）的前一天
          slice(2026, 10, 1, 9, 60),
        ],
        today: day(2026, 10, 7),
      );

      expect(
        <int>[for (final FocusDaySummary day in snapshot.week) day.day],
        <int>[for (int i = 0; i < kHomeWidgetDays; i++) day(2026, 10, 1 + i)],
      );
      expect(snapshot.week.first.seconds, 60);
      expect(snapshot.week.last.day, day(2026, 10, 7));
      expect(
        snapshot.week.fold<int>(
          0,
          (int sum, FocusDaySummary day) => sum + day.seconds,
        ),
        60,
        reason: '窗口外那条不该混进来',
      );
    });

    test('同一天几段会累加，柱子的档位看合计', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[
          slice(2026, 10, 6, 9, 20 * 60),
          slice(2026, 10, 6, 14, 20 * 60),
          slice(2026, 10, 6, 19, 25 * 60),
        ],
        today: day(2026, 10, 7),
      );

      expect(snapshot.week[5].seconds, 65 * 60);
      expect(snapshot.week[5].sessions, 3);
      expect(snapshot.levels[5], FocusHeat.heavy.index);
    });
  });

  group('HomeWidgetSnapshot.toMap · 真正发过平台侧的东西', () {
    test('七个档位按天升序排开，键名固定', () {
      final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.fromSlices(
        <FocusSlice>[
          slice(2026, 10, 1, 9, 25 * 60),
          slice(2026, 10, 7, 9, 90 * 60),
        ],
        today: day(2026, 10, 7),
      );

      final Map<String, Object?> map = snapshot.toMap();
      expect(map.keys.toSet(), <String>{
        'today',
        'seconds',
        'sessions',
        'levels',
        'headline',
        'caption',
      });
      expect(map['today'], day(2026, 10, 7));
      expect(map['seconds'], 90 * 60);
      expect(map['sessions'], 1);
      expect(map['headline'], '今天 1 小时 30 分');
      expect(map['caption'], '共 1 段');
      expect(map['levels'], <int>[
        FocusHeat.medium.index, // 10-01：25 分钟，过了「少」那一档
        FocusHeat.none.index, // 10-02
        FocusHeat.none.index, // 10-03
        FocusHeat.none.index, // 10-04
        FocusHeat.none.index, // 10-05
        FocusHeat.none.index, // 10-06
        FocusHeat.heavy.index, // 10-07
      ]);
    });
  });
}
