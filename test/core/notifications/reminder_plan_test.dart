import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/core/notifications/reminder_plan.dart';
import 'package:now_todo/core/utils/time.dart';

/// 构造一条 [ReminderSource]，默认「未完成、已启用、一次性」。
ReminderSource source({
  String id = 'r1',
  String taskId = 't1',
  String taskTitle = '写周报',
  bool taskCompleted = false,
  required DateTime at,
  ReminderRepeatType repeat = ReminderRepeatType.once,
  bool enabled = true,
}) => ReminderSource(
  id: id,
  taskId: taskId,
  taskTitle: taskTitle,
  taskCompleted: taskCompleted,
  remindAt: at.utcMillis,
  repeatType: repeat,
  enabled: enabled,
);

void main() {
  group('nextOccurrence · 仅一次', () {
    final DateTime anchor = DateTime(2026, 5, 10, 9);

    test('还没到点就返回锚点本身', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.once,
          now: DateTime(2026, 5, 10, 8),
        ),
        anchor,
      );
    });

    test('已过点返回 null', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.once,
          now: DateTime(2026, 5, 10, 9, 1),
        ),
        isNull,
      );
    });

    test('恰好等于当前时刻也算过期，不再排一次', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.once,
          now: anchor,
        ),
        isNull,
      );
    });
  });

  group('nextOccurrence · 每天', () {
    final DateTime anchor = DateTime(2026, 5, 10, 9);

    test('今天的点还没到 → 就是今天', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.daily,
          now: DateTime(2026, 5, 12, 8),
        ),
        DateTime(2026, 5, 12, 9),
      );
    });

    test('今天的点已过 → 明天', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.daily,
          now: DateTime(2026, 5, 12, 10),
        ),
        DateTime(2026, 5, 13, 9),
      );
    });

    test('锚点在未来时原样返回，不做回退', () {
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.daily,
          now: DateTime(2026, 5, 1),
        ),
        anchor,
      );
    });

    test('锚点在三年前也能算出正确的下一次，且时分秒不变', () {
      expect(
        nextOccurrence(
          anchor: DateTime(2023, 1, 15, 9, 30),
          repeat: ReminderRepeatType.daily,
          now: DateTime(2026, 5, 12, 10),
        ),
        DateTime(2026, 5, 13, 9, 30),
      );
    });
  });

  group('nextOccurrence · 每周', () {
    test('按 7 天推进，而不是按「本周剩下的天数」', () {
      // 2026-05-04 是周一。
      final DateTime anchor = DateTime(2026, 5, 4, 9);
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.weekly,
          now: DateTime(2026, 5, 12, 8),
        ),
        DateTime(2026, 5, 18, 9),
      );
    });
  });

  group('nextOccurrence · 每月', () {
    test('1 月 31 日的锚点，2 月夹到 28 日', () {
      expect(
        nextOccurrence(
          anchor: DateTime(2026, 1, 31, 9),
          repeat: ReminderRepeatType.monthly,
          now: DateTime(2026, 2, 1),
        ),
        DateTime(2026, 2, 28, 9),
      );
    });

    test('夹到月末之后**不会永久漂移**：3 月要回到 31 日', () {
      // 这是最容易写错的一条。如果把「上一次的结果」当作下一次的锚点，
      // 一个每月 31 日的提醒在 2 月之后会永远停在 28 日。
      final DateTime anchor = DateTime(2026, 1, 31, 9);
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.monthly,
          now: DateTime(2026, 3, 1),
        ),
        DateTime(2026, 3, 31, 9),
      );
      expect(
        nextOccurrence(
          anchor: anchor,
          repeat: ReminderRepeatType.monthly,
          now: DateTime(2026, 4, 1),
        ),
        DateTime(2026, 4, 30, 9),
      );
    });

    test('闰日锚点在平年夹到 2 月 28 日', () {
      expect(
        nextOccurrence(
          anchor: DateTime(2028, 2, 29, 9),
          repeat: ReminderRepeatType.monthly,
          now: DateTime(2029, 2, 1),
        ),
        DateTime(2029, 2, 28, 9),
      );
    });

    test('29 日的锚点在 1 月有 29 号时不会跳到 2 月', () {
      expect(
        nextOccurrence(
          anchor: DateTime(2028, 2, 29, 9),
          repeat: ReminderRepeatType.monthly,
          now: DateTime(2029, 1, 1),
        ),
        DateTime(2029, 1, 29, 9),
      );
    });
  });

  group('addMonthsClamped', () {
    test('溢出时夹到目标月最后一天', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonthsClamped(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
    });

    test('不溢出时保持日期号', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
    });

    test('跨年正确', () {
      expect(
        addMonthsClamped(DateTime(2026, 12, 15), 1),
        DateTime(2027, 1, 15),
      );
      expect(
        addMonthsClamped(DateTime(2026, 1, 15), -1),
        DateTime(2025, 12, 15),
      );
    });

    test('保留时分秒', () {
      expect(
        addMonthsClamped(DateTime(2026, 1, 31, 9, 30, 15), 1),
        DateTime(2026, 2, 28, 9, 30, 15),
      );
    });
  });

  group('buildReminderPlan', () {
    final DateTime now = DateTime(2026, 5, 12, 10);

    test('空输入给出空计划', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: const <ReminderSource>[],
        now: now,
      );
      expect(plan.isEmpty, isTrue);
    });

    test('未来的提醒进 schedule，并带上任务上下文', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[
          source(at: DateTime(2026, 5, 12, 18), taskTitle: '买菜'),
        ],
        now: now,
      );
      expect(plan.cancel, isEmpty);
      expect(plan.schedule, hasLength(1));
      expect(plan.schedule.single.taskTitle, '买菜');
      expect(plan.schedule.single.at, DateTime(2026, 5, 12, 18));
      expect(plan.schedule.single.taskId, 't1');
    });

    test('已过点的一次性提醒进 cancel —— 留着会让「待响条数」对不上', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[source(at: DateTime(2026, 5, 11, 18))],
        now: now,
      );
      expect(plan.schedule, isEmpty);
      expect(plan.cancel, <String>['r1']);
    });

    test('被关掉的提醒进 cancel', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[
          source(at: DateTime(2026, 5, 12, 18), enabled: false),
        ],
        now: now,
      );
      expect(plan.schedule, isEmpty);
      expect(plan.cancel, <String>['r1']);
    });

    test('任务已完成时进 cancel，但记录保留（恢复任务后会自动重新排上）', () {
      final ReminderSource entry = source(
        at: DateTime(2026, 5, 12, 18),
        taskCompleted: true,
      );
      final ReminderPlan done = buildReminderPlan(
        reminders: <ReminderSource>[entry],
        now: now,
      );
      expect(done.cancel, <String>['r1']);

      final ReminderPlan restored = buildReminderPlan(
        reminders: <ReminderSource>[source(at: DateTime(2026, 5, 12, 18))],
        now: now,
      );
      expect(restored.schedule, hasLength(1));
    });

    test('已过点但会重复的提醒仍然要排上，取下一次触发', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[
          source(at: DateTime(2026, 2, 1, 9), repeat: ReminderRepeatType.daily),
        ],
        now: now,
      );
      expect(plan.cancel, isEmpty);
      expect(plan.schedule.single.at, DateTime(2026, 5, 13, 9));
    });

    test('同一个 id 出现两次只处理一次', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[
          source(at: DateTime(2026, 5, 12, 18)),
          source(at: DateTime(2026, 5, 12, 18)),
        ],
        now: now,
      );
      expect(plan.schedule, hasLength(1));
      expect(plan.cancel, isEmpty);
    });

    test('混合场景：三条排上、两条撤销', () {
      final ReminderPlan plan = buildReminderPlan(
        reminders: <ReminderSource>[
          source(id: 'a', at: DateTime(2026, 5, 12, 18)),
          source(id: 'b', at: DateTime(2026, 5, 13, 9)),
          source(
            id: 'c',
            at: DateTime(2026, 2, 1, 9),
            repeat: ReminderRepeatType.weekly,
          ),
          source(id: 'd', at: DateTime(2026, 5, 10, 9)),
          source(id: 'e', at: DateTime(2026, 5, 14, 9), enabled: false),
        ],
        now: now,
      );
      expect(
        plan.schedule.map((ReminderSlot s) => s.reminderId).toList(),
        <String>['a', 'b', 'c'],
      );
      expect(plan.cancel, <String>['d', 'e']);
    });
  });
}
