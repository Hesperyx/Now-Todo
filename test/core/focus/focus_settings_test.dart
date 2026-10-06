import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/focus/focus_settings.dart';
import 'package:now_todo/core/models/enums.dart';

void main() {
  group('minutesRangeFor', () {
    test('专注是 5–180 分钟', () {
      final ({int min, int max}) range = minutesRangeFor(
        FocusSessionKind.focus,
      );
      expect(range.min, 5);
      expect(range.max, 180);
    });

    test('两种休息都是 1–60 分钟', () {
      for (final FocusSessionKind kind in const <FocusSessionKind>[
        FocusSessionKind.shortBreak,
        FocusSessionKind.longBreak,
      ]) {
        final ({int min, int max}) range = minutesRangeFor(kind);
        expect(range.min, 1, reason: kind.name);
        expect(range.max, 60, reason: kind.name);
      }
    });

    test('每一种会话类型都有一条分支，没有落到兜底', () {
      for (final FocusSessionKind kind in FocusSessionKind.values) {
        final ({int min, int max}) range = minutesRangeFor(kind);
        expect(range.min, greaterThan(0), reason: kind.name);
        expect(range.max, greaterThanOrEqualTo(range.min), reason: kind.name);
      }
    });
  });

  group('validateMinutes', () {
    test('专注：边界上都算合法', () {
      expect(validateMinutes(5, FocusSessionKind.focus), isNull);
      expect(validateMinutes(25, FocusSessionKind.focus), isNull);
      expect(validateMinutes(180, FocusSessionKind.focus), isNull);
    });

    test('专注：越界时文案里带着边界本身', () {
      // 文案里必须有数字：只说「太长了」的话用户还得自己去试。
      expect(validateMinutes(4, FocusSessionKind.focus), '太短了，最少 5 分钟。');
      expect(validateMinutes(181, FocusSessionKind.focus), '太长了，最多 180 分钟。');
    });

    test('休息：边界上都算合法', () {
      expect(validateMinutes(1, FocusSessionKind.shortBreak), isNull);
      expect(validateMinutes(60, FocusSessionKind.longBreak), isNull);
    });

    test('休息：越界时文案里的数字跟着类型走', () {
      expect(validateMinutes(0, FocusSessionKind.shortBreak), '太短了，最少 1 分钟。');
      expect(validateMinutes(61, FocusSessionKind.shortBreak), '太长了，最多 60 分钟。');
      expect(validateMinutes(61, FocusSessionKind.longBreak), '太长了，最多 60 分钟。');
    });

    test('同一个数字在专注与休息两边结论不同', () {
      // 4 分钟对休息是合法的、对专注不合法 —— 校验必须看类型，不能只看数字。
      expect(validateMinutes(4, FocusSessionKind.focus), isNotNull);
      expect(validateMinutes(4, FocusSessionKind.shortBreak), isNull);
    });

    test('手滑多打一位数也被拦住', () {
      expect(validateMinutes(2500, FocusSessionKind.focus), isNotNull);
      expect(validateMinutes(999, FocusSessionKind.longBreak), isNotNull);
    });

    test('负数按「太短」处理', () {
      expect(validateMinutes(-25, FocusSessionKind.focus), '太短了，最少 5 分钟。');
    });
  });

  group('breakAfterFocus', () {
    test('每 4 轮给一次长休息', () {
      for (final int rounds in const <int>[1, 2, 3, 5, 6, 7, 9]) {
        expect(
          breakAfterFocus(
            completedFocusRounds: rounds,
            roundsBeforeLongBreak: 4,
          ),
          FocusSessionKind.shortBreak,
          reason: '第 $rounds 轮',
        );
      }
      for (final int rounds in const <int>[4, 8, 12]) {
        expect(
          breakAfterFocus(
            completedFocusRounds: rounds,
            roundsBeforeLongBreak: 4,
          ),
          FocusSessionKind.longBreak,
          reason: '第 $rounds 轮',
        );
      }
    });

    test('配置成每 1 轮，每次都长休息', () {
      expect(
        breakAfterFocus(completedFocusRounds: 1, roundsBeforeLongBreak: 1),
        FocusSessionKind.longBreak,
      );
    });

    test('配置成 0 或负数时一律短休息，而不是除零崩掉', () {
      for (final int configured in const <int>[0, -1, -4]) {
        expect(
          breakAfterFocus(
            completedFocusRounds: 4,
            roundsBeforeLongBreak: configured,
          ),
          FocusSessionKind.shortBreak,
          reason: '配置成 $configured',
        );
      }
    });

    test('累计轮数为 0 时是短休息', () {
      // `0 % 4 == 0` 会算出长休息，但传进来 0 说明刚结束的那一段不是专注。
      expect(
        breakAfterFocus(completedFocusRounds: 0, roundsBeforeLongBreak: 4),
        FocusSessionKind.shortBreak,
      );
    });
  });

  group('kindAfterBreak', () {
    test('休息之后一律回到专注', () {
      expect(kindAfterBreak(), FocusSessionKind.focus);
    });
  });
}
