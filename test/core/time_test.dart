import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/utils/time.dart';

void main() {
  group('dayOnlyMillis', () {
    test('把一天里的任意时刻压到本地零点', () {
      final DateTime afternoon = DateTime(2026, 10, 8, 13, 45, 12);
      final DateTime stored = fromUtcMillis(dayOnlyMillis(afternoon));

      expect(stored.year, 2026);
      expect(stored.month, 10);
      expect(stored.day, 8);
      expect(stored.hour, 0);
      expect(stored.minute, 0);
      expect(stored.second, 0);
    });

    test('同一天的不同时刻算出来是同一个值', () {
      expect(
        dayOnlyMillis(DateTime(2026, 10, 8, 0, 0, 1)),
        dayOnlyMillis(DateTime(2026, 10, 8, 23, 59, 59)),
      );
    });
  });

  group('当天区间', () {
    final DateTime day = DateTime(2026, 10, 8, 9);

    test('左闭右开', () {
      final int start = dayOnlyMillis(day);
      final int end = endOfLocalDayMillis(day);

      expect(start, lessThan(end));
      expect(DateTime(2026, 10, 8).utcMillis, start);
      expect(DateTime(2026, 10, 8, 23, 59, 59).utcMillis, lessThan(end));
      // 次日零点已经落在区间外，否则跨天的任务会被算进当天两次。
      expect(DateTime(2026, 10, 9).utcMillis, end);
    });

    test('isSameLocalDay 只认本地日期', () {
      expect(
        isSameLocalDay(
          DateTime(2026, 10, 8, 0, 5).utcMillis,
          DateTime(2026, 10, 8, 22, 5).utcMillis,
        ),
        isTrue,
      );
      expect(
        isSameLocalDay(
          DateTime(2026, 10, 8, 23, 55).utcMillis,
          DateTime(2026, 10, 9, 0, 5).utcMillis,
        ),
        isFalse,
      );
    });
  });

  group('isOverdue', () {
    test('没有截止时间永远不算逾期', () {
      expect(isOverdue(null, nowMillis: 1000), isFalse);
    });

    test('早于此刻才算逾期，等于不算', () {
      expect(isOverdue(999, nowMillis: 1000), isTrue);
      expect(isOverdue(1000, nowMillis: 1000), isFalse);
      expect(isOverdue(1001, nowMillis: 1000), isFalse);
    });
  });

  group('格式化', () {
    final int millis = DateTime(2026, 1, 5, 9, 7).utcMillis;

    test('日期补零', () {
      expect(formatDate(millis), '2026-01-05');
    });

    test('日期时间补零', () {
      expect(formatDateTime(millis), '2026-01-05 09:07');
    });
  });

  test('utcMillis 与 fromUtcMillis 互为逆运算', () {
    final DateTime original = DateTime(2026, 10, 8, 13, 45, 12, 345);

    expect(fromUtcMillis(original.utcMillis), original);
  });
}
