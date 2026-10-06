import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/notifications/notification_ids.dart';

void main() {
  group('stableHash', () {
    test('同一个输入永远给出同一个值', () {
      expect(stableHash('reminder-abc'), stableHash('reminder-abc'));
      expect(stableHash(''), stableHash(''));
    });

    test('结果恒为非负', () {
      // 非负是硬要求：Android 的通知 id 是 jint，负数和「未设置」的哨兵
      // 放在一起读很容易出错。
      final List<String> samples = <String>[
        '',
        'a',
        'reminder-0',
        '提醒',
        '${List<int>.generate(200, (int i) => i)}',
      ];
      for (final String sample in samples) {
        expect(stableHash(sample), greaterThanOrEqualTo(0));
      }
    });

    test('不同输入不冲突：1000 个样本里没有碰撞', () {
      // 这条是防止哈希实现写错（比如忘了乘质数）的主要护栏。
      // 真空里 1000 个样本撞进 2^31 个桶的概率可以忽略，
      // 一旦真的有碰撞，说明实现已经退化成弱哈希。
      final Set<int> seen = <int>{};
      for (int i = 0; i < 1000; i++) {
        expect(
          seen.add(stableHash('reminder-$i')),
          isTrue,
          reason: '第 $i 个样本碰撞',
        );
      }
    });
  });

  group('NotificationIds', () {
    test('提醒 id 全部落在提醒区间，不会撞上计时用的固定 id', () {
      for (int i = 0; i < 500; i++) {
        final int id = NotificationIds.forReminder('r-$i');
        expect(id, greaterThanOrEqualTo(1000));
        expect(NotificationIds.isReminder(id), isTrue);
      }
      expect(NotificationIds.isReminder(NotificationIds.focusOngoing), isFalse);
      expect(
        NotificationIds.isReminder(NotificationIds.focusFinished),
        isFalse,
      );
    });
  });
}
