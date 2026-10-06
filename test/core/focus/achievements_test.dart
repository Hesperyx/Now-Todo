// 徽章判定的用例。
//
// 这里咬的是**口径**与**边界**：累计到底算不算 0 秒的记录、连续天数在
// 「今天还没开始」时算不算断、「单日」与「单段」有没有混、界值（正好达到
// 目标）算不算解锁。判定错了不会报错，只会安静地发错徽章。

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/achievements.dart';
import 'package:now_todo/core/focus/focus_stats.dart';
import 'package:now_todo/core/utils/time.dart';

void main() {
  int day(int year, int month, int date) =>
      dayOnlyMillis(DateTime(year, month, date));

  /// 一段专注。`logicalDate` 默认按开始时刻所在的那天。
  FocusSlice slice(
    int year,
    int month,
    int date,
    int hour,
    int seconds, {
    int? logicalDate,
  }) {
    final DateTime startedAt = DateTime(year, month, date, hour);
    return FocusSlice(
      logicalDate: logicalDate ?? dayOnlyMillis(startedAt),
      startedAt: startedAt.utcMillis,
      seconds: seconds,
    );
  }

  AchievementFacts factsOf(List<FocusSlice> slices, {int? today}) =>
      AchievementFacts.from(slices: slices, today: today ?? day(2026, 10, 7));

  AchievementProgress progressOf(
    List<FocusSlice> slices,
    String key, {
    int? today,
  }) {
    final AchievementFacts facts = factsOf(slices, today: today);
    return evaluateAchievements(
      facts,
    ).firstWhere((AchievementProgress item) => item.achievement.key == key);
  }

  group('AchievementFacts · 累计与计数', () {
    test('累计时长不算 0 秒的记录，条数算', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 1, 9, 1500),
        slice(2026, 10, 2, 9, 0),
        slice(2026, 10, 3, 9, 1500),
      ]);
      expect(facts.totalFocusSeconds, 3000);
      expect(facts.sessionCount, 3);
    });

    test('同一天三段只算一天，但单日累计与条数都看得见', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 5, 9, 1500),
        slice(2026, 10, 5, 14, 1800),
        slice(2026, 10, 5, 19, 900),
      ]);
      expect(facts.daysWithData, 1);
      expect(facts.bestDaySeconds, 4200);
      expect(facts.bestDaySessions, 3);
    });

    test('单段最长取的是单段，不是某天的合计', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 5, 9, 3000),
        slice(2026, 10, 5, 14, 3000),
      ]);
      expect(facts.longestSessionSeconds, 3000);
      expect(facts.bestDaySeconds, 6000);
    });

    test('最忙的一天不一定是最后一天', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 1, 9, 7200),
        slice(2026, 10, 6, 9, 600),
        slice(2026, 10, 7, 9, 600),
      ]);
      expect(facts.bestDaySeconds, 7200);
      expect(facts.daysWithData, 3);
    });

    test('全都只有 0 秒记录时：有时长的天数是 0', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 6, 9, 0),
        slice(2026, 10, 7, 9, 0),
      ]);
      expect(facts.daysWithData, 0);
      expect(facts.sessionCount, 2);
      expect(facts.totalFocusSeconds, 0);
      expect(facts.currentStreak, 0);
    });
  });

  group('AchievementFacts · 早晚', () {
    test('5:59 开始算早起，6:00 不算', () {
      expect(
        factsOf(<FocusSlice>[slice(2026, 10, 6, 5, 1500)]).earlySessions,
        1,
      );
      expect(
        factsOf(<FocusSlice>[slice(2026, 10, 6, 6, 1500)]).earlySessions,
        0,
      );
    });

    test('22:00 开始算夜猫子，21:59 不算', () {
      expect(
        factsOf(<FocusSlice>[slice(2026, 10, 6, 22, 600)]).lateSessions,
        1,
      );
      expect(
        factsOf(<FocusSlice>[slice(2026, 10, 6, 21, 600)]).lateSessions,
        0,
      );
    });

    test('看的是开始那一刻的钟点：23:30 开始的跨夜专注算夜猫子，不算早起', () {
      final FocusSlice overnight = slice(2026, 10, 6, 23, 7200);
      final AchievementFacts facts = factsOf(<FocusSlice>[overnight]);
      expect(facts.lateSessions, 1);
      expect(facts.earlySessions, 0);
      // 逻辑日仍然是开始那天，跟「午夜模式」的口径一致。
      expect(facts.daysWithData, 1);
      expect(facts.bestDaySessions, 1);
    });
  });

  group('AchievementFacts · 连续天数', () {
    test('今天有记录时，连续天数含今天', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 5, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
        slice(2026, 10, 7, 9, 1500),
      ]);
      expect(facts.currentStreak, 3);
      expect(facts.longestStreak, 3);
    });

    test('今天还没开始时不算断，从昨天数起', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 5, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
      ]);
      expect(facts.currentStreak, 2);
    });

    test('当前连续与历史最长是两件事', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 9, 28, 9, 1500),
        slice(2026, 9, 29, 9, 1500),
        slice(2026, 9, 30, 9, 1500),
        slice(2026, 10, 7, 9, 1500),
      ]);
      expect(facts.currentStreak, 1);
      expect(facts.longestStreak, 3);
    });
  });

  group('evaluateAchievements · 一次判完全部徽章', () {
    test('14 枚，顺序固定，key 不重复', () {
      final List<AchievementProgress> progress = evaluateAchievements(
        factsOf(const <FocusSlice>[]),
      );
      expect(progress.length, 14);
      expect(
        progress.map((AchievementProgress item) => item.achievement.key),
        kAchievements.map((Achievement achievement) => achievement.key),
      );
      expect(
        <String>{
          for (final Achievement achievement in kAchievements) achievement.key,
        }.length,
        14,
      );
    });

    test('一条记录都没有时：一枚都没解锁', () {
      final List<AchievementProgress> progress = evaluateAchievements(
        factsOf(const <FocusSlice>[]),
      );
      expect(unlockedCount(progress), 0);
      for (final AchievementProgress item in progress) {
        expect(item.unlocked, isFalse);
        expect(item.ratio, 0);
      }
    });

    test('第一段专注就解锁「第一步」，一小时还差得远', () {
      final List<AchievementProgress> progress = evaluateAchievements(
        factsOf(<FocusSlice>[slice(2026, 10, 7, 9, 1500)]),
      );
      expect(unlockedCount(progress), 1);
      final AchievementProgress first = progress.firstWhere(
        (AchievementProgress item) => item.achievement.key == 'first_session',
      );
      expect(first.unlocked, isTrue);
      expect(first.progressText, '1 / 1 次');
      final AchievementProgress hour = progress.firstWhere(
        (AchievementProgress item) => item.achievement.key == 'hours_1',
      );
      expect(hour.unlocked, isFalse);
      expect(hour.value, 0);
      expect(hour.remaining, 1);
      expect(hour.progressText, '0 / 1 小时');
    });

    test('一段 90 分钟同时解锁「第一步」「满一小时」「长跑」', () {
      final List<AchievementProgress> progress = evaluateAchievements(
        factsOf(<FocusSlice>[slice(2026, 10, 7, 9, 90 * 60)]),
      );
      expect(unlockedCount(progress), 3);
    });

    test('「满一小时」的界值：3599 秒不算，3600 秒算', () {
      expect(
        progressOf(<FocusSlice>[
          slice(2026, 10, 7, 9, 3599),
        ], 'hours_1').unlocked,
        isFalse,
      );
      expect(
        progressOf(<FocusSlice>[
          slice(2026, 10, 7, 9, 3600),
        ], 'hours_1').unlocked,
        isTrue,
      );
    });

    test('「连续三天」看的是历史最长，今天断了照样解锁', () {
      final List<FocusSlice> slices = <FocusSlice>[
        slice(2026, 9, 28, 9, 1500),
        slice(2026, 9, 29, 9, 1500),
        slice(2026, 9, 30, 9, 1500),
      ];
      expect(progressOf(slices, 'streak_3').unlocked, isTrue);
      expect(progressOf(slices, 'streak_7').unlocked, isFalse);
      // 「当前连续」是 0，但这枚徽章不看它。
      expect(factsOf(slices).currentStreak, 0);
    });

    test('「一天四段」数的是条数，0 秒的那段也算坐下来过', () {
      final List<FocusSlice> slices = <FocusSlice>[
        slice(2026, 10, 7, 9, 1500),
        slice(2026, 10, 7, 11, 0),
        slice(2026, 10, 7, 14, 1500),
        slice(2026, 10, 7, 19, 1500),
      ];
      expect(progressOf(slices, 'day_four').unlocked, isTrue);
      expect(progressOf(slices, 'day_four').progressText, '4 / 4 次');
    });

    test('「深度一天」是单日累计：两天各 90 分钟不算', () {
      final List<FocusSlice> split = <FocusSlice>[
        slice(2026, 10, 6, 9, 90 * 60),
        slice(2026, 10, 7, 9, 90 * 60),
      ];
      expect(progressOf(split, 'deep_day').unlocked, isFalse);
      final List<FocusSlice> oneDay = <FocusSlice>[
        slice(2026, 10, 7, 9, 90 * 60),
        slice(2026, 10, 7, 20, 90 * 60),
      ];
      expect(progressOf(oneDay, 'deep_day').unlocked, isTrue);
    });

    test('「早起鸟」「夜猫子」各看各的钟点', () {
      expect(
        progressOf(<FocusSlice>[
          slice(2026, 10, 7, 5, 1500),
        ], 'early_bird').unlocked,
        isTrue,
      );
      expect(
        progressOf(<FocusSlice>[
          slice(2026, 10, 7, 5, 1500),
        ], 'night_owl').unlocked,
        isFalse,
      );
      expect(
        progressOf(<FocusSlice>[
          slice(2026, 10, 7, 23, 1500),
        ], 'night_owl').unlocked,
        isTrue,
      );
    });

    test('一百段与一百小时在小数据下都还没到', () {
      final List<FocusSlice> slices = <FocusSlice>[
        for (int i = 0; i < 10; i++) slice(2026, 10, 1 + i, 9, 3600),
      ];
      final List<AchievementProgress> progress = evaluateAchievements(
        factsOf(slices),
      );
      final AchievementProgress hundred = progress.firstWhere(
        (AchievementProgress item) => item.achievement.key == 'sessions_100',
      );
      expect(hundred.unlocked, isFalse);
      expect(hundred.progressText, '10 / 100 次');
      expect(hundred.ratio, closeTo(0.1, 1e-9));
      final AchievementProgress hours = progress.firstWhere(
        (AchievementProgress item) => item.achievement.key == 'hours_100',
      );
      expect(hours.unlocked, isFalse);
      expect(hours.progressText, '10 / 100 小时');
    });
  });

  group('AchievementProgress · 进度与文案', () {
    test('值超出目标时进度封顶，但值本身照实保留', () {
      final AchievementProgress first = progressOf(<FocusSlice>[
        slice(2026, 10, 7, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
      ], 'first_session');
      expect(first.value, 2);
      expect(first.unlocked, isTrue);
      expect(first.ratio, 1);
      expect(first.remaining, 0);
      expect(first.progressText, '1 / 1 次');
    });

    test('还差多少是目标减当前，不含超出部分', () {
      final AchievementProgress ten = progressOf(<FocusSlice>[
        slice(2026, 10, 7, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
      ], 'sessions_10');
      expect(ten.value, 2);
      expect(ten.remaining, 8);
      expect(ten.progressText, '2 / 10 次');
      expect(ten.ratio, closeTo(0.2, 1e-9));
    });
  });

  group('AchievementBoard · 页面要的那点东西', () {
    test('一条记录都没有时是空的', () {
      final AchievementFacts facts = factsOf(const <FocusSlice>[]);
      final AchievementBoard board = AchievementBoard(
        facts: facts,
        progress: evaluateAchievements(facts),
      );
      expect(board.isEmpty, isTrue);
      expect(board.unlocked, 0);
      expect(board.total, 14);
    });

    test('只有 0 秒记录时不算空：启动了计时器就解锁「第一步」', () {
      final AchievementFacts facts = factsOf(<FocusSlice>[
        slice(2026, 10, 7, 9, 0),
      ]);
      final AchievementBoard board = AchievementBoard(
        facts: facts,
        progress: evaluateAchievements(facts),
      );
      expect(board.isEmpty, isFalse);
      // 条数类只认「启动过」；时长类一点都不沾。
      expect(board.unlocked, 1);
      expect(board.unlocked, unlockedCount(board.progress));
      expect(
        progressOf(<FocusSlice>[slice(2026, 10, 7, 9, 0)], 'hours_1').unlocked,
        isFalse,
      );
      expect(
        progressOf(<FocusSlice>[slice(2026, 10, 7, 9, 0)], 'marathon').unlocked,
        isFalse,
      );
    });
  });

  group('判定完全由记录推出来', () {
    test('同一批记录重算两次结果一样', () {
      final List<FocusSlice> slices = <FocusSlice>[
        slice(2026, 10, 5, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
      ];
      final List<AchievementProgress> once = evaluateAchievements(
        factsOf(slices),
      );
      final List<AchievementProgress> twice = evaluateAchievements(
        factsOf(slices),
      );
      for (int i = 0; i < once.length; i++) {
        expect(twice[i].value, once[i].value);
        expect(twice[i].unlocked, once[i].unlocked);
      }
    });

    test('只有「现在几点」会变结果，历史长短不随今天漂', () {
      final List<FocusSlice> slices = <FocusSlice>[
        slice(2026, 10, 5, 9, 1500),
        slice(2026, 10, 6, 9, 1500),
      ];
      final AchievementFacts yesterday = factsOf(
        slices,
        today: day(2026, 10, 6),
      );
      final AchievementFacts later = factsOf(slices, today: day(2026, 10, 9));
      expect(yesterday.currentStreak, 2);
      expect(later.currentStreak, 0);
      // 累计与最长连续是记录的属性，跟「今天」无关。
      expect(later.totalFocusSeconds, yesterday.totalFocusSeconds);
      expect(later.longestStreak, yesterday.longestStreak);
      expect(later.bestDaySeconds, yesterday.bestDaySeconds);
    });
  });
}
