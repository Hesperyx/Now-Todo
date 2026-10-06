import '../models/enums.dart';
import '../utils/time.dart';

/// 提醒调度的**纯计算**部分。
///
/// 这里只回答「哪些提醒该出现在系统里、各自定在什么时刻」，不接触
/// `flutter_local_notifications`，也不碰数据库。把它单独拆出来的理由是：
///
/// - 「下一次该响在什么时候」是重复提醒里最容易错的地方（跨月、月末、闰年、
///   夏令时），必须是可穷举测试的纯函数；
/// - 真正调系统 API 的那层没有逻辑，错也错不到哪里去。
///
/// 时刻的表示约定：**入口是存储层的 UTC 毫秒，出口是本地 `DateTime`。**
/// 系统闹钟按设备本地时间排程，所以换算必须在排程前完成，见
/// `docs/ARCHITECTURE.md` §5。

/// 一条待调度的提醒，外加它所属任务的最小上下文。
///
/// 任务标题要跟着进来，是因为通知正文得写「该做什么」；只带任务 id 的话
/// 调度层还得回查数据库，那就不再是纯函数了。
class ReminderSource {
  const ReminderSource({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.taskCompleted,
    required this.remindAt,
    required this.repeatType,
    required this.enabled,
  });

  final String id;
  final String taskId;
  final String taskTitle;

  /// 任务已完成。已完成的提醒不再排程 —— 但**保留在数据库里**，
  /// 用户把任务恢复成未完成时它会重新生效。
  final bool taskCompleted;

  /// 提醒时刻，UTC 毫秒。
  final int remindAt;

  final ReminderRepeatType repeatType;

  /// 关掉但保留配置的提醒不排程。
  final bool enabled;
}

/// 一条最终要写进系统闹钟的提醒。
class ReminderSlot {
  const ReminderSlot({
    required this.reminderId,
    required this.taskId,
    required this.taskTitle,
    required this.at,
    required this.repeatType,
  });

  final String reminderId;
  final String taskId;
  final String taskTitle;

  /// 本地绝对时刻。
  final DateTime at;

  final ReminderRepeatType repeatType;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot &&
      other.reminderId == reminderId &&
      other.taskId == taskId &&
      other.taskTitle == taskTitle &&
      other.at == at &&
      other.repeatType == repeatType;

  @override
  int get hashCode =>
      Object.hash(reminderId, taskId, taskTitle, at, repeatType);

  @override
  String toString() => 'ReminderSlot($reminderId → $at, $repeatType)';
}

/// 一次同步动作算出来的完整结果。
///
/// 做成「全量计划」而不是增量指令，是为了让同步变成幂等的：无论当前系统里
/// 是什么状态，把计划整个应用一遍就收敛到正确状态。增量指令一旦漏了一条，
/// 那条通知就永远留在系统里。
class ReminderPlan {
  const ReminderPlan({
    this.schedule = const <ReminderSlot>[],
    this.cancel = const <String>[],
  });

  /// 需要注册到系统的提醒。
  final List<ReminderSlot> schedule;

  /// 需要从系统撤销的提醒 id（被关掉、任务已完成、或一次性提醒已过点）。
  final List<String> cancel;

  bool get isEmpty => schedule.isEmpty && cancel.isEmpty;
}

/// 算出 [reminders] 在 [now] 这一刻应有的排程状态。
///
/// [now] 由调用方传入而不是内部取 `DateTime.now()`：一是可测，二是同一批
/// 计算必须用同一个「现在」，否则跨过整点时会算出一半用旧时间、一半用新时间。
ReminderPlan buildReminderPlan({
  required List<ReminderSource> reminders,
  required DateTime now,
}) {
  final List<ReminderSlot> schedule = <ReminderSlot>[];
  final List<String> cancel = <String>[];
  final Set<String> seen = <String>{};

  for (final ReminderSource source in reminders) {
    // 同一个提醒出现两次就只算一次。数据库有主键约束，理论上不会发生，
    // 但这里是纯函数，不该假设调用方一定干净。
    if (!seen.add(source.id)) continue;

    if (!source.enabled || source.taskCompleted) {
      cancel.add(source.id);
      continue;
    }

    final DateTime? at = nextOccurrence(
      anchor: fromUtcMillis(source.remindAt),
      repeat: source.repeatType,
      now: now,
    );
    if (at == null) {
      // 一次性提醒已经过点：把它撤销掉。留着只会让「系统里还有几条待响」
      // 这个数字对不上，排查时误导人。
      cancel.add(source.id);
      continue;
    }

    schedule.add(
      ReminderSlot(
        reminderId: source.id,
        taskId: source.taskId,
        taskTitle: source.taskTitle,
        at: at,
        repeatType: source.repeatType,
      ),
    );
  }

  return ReminderPlan(schedule: schedule, cancel: cancel);
}

/// [anchor] 之后（含当前这一刻之后）的下一次触发时刻。没有下一次则返回 `null`。
///
/// [anchor] 是用户最初设定的时刻，本地时间。重复规则都以它为锚点推进，
/// 而不是以「上次触发时刻」递推 —— 后者会在每次跨越夏令时的时候累积漂移。
DateTime? nextOccurrence({
  required DateTime anchor,
  required ReminderRepeatType repeat,
  required DateTime now,
}) {
  switch (repeat) {
    case ReminderRepeatType.once:
      // 恰好等于 now 也算过期：闹钟已经在响了，再排一次是重复通知。
      return anchor.isAfter(now) ? anchor : null;

    case ReminderRepeatType.daily:
      return _stepByDays(anchor: anchor, now: now, step: 1);

    case ReminderRepeatType.weekly:
      return _stepByDays(anchor: anchor, now: now, step: 7);

    case ReminderRepeatType.monthly:
      return _stepByMonths(anchor: anchor, now: now);
  }
}

/// 每次循环的上限。
///
/// 锚点在很久以前时，`while` 需要跑很多轮。理论上界与「多少天算离谱」有关，
/// 给一个宽松但有限的值：真踩到上界说明锚点是脏数据（比如 1970 年），
/// 这时候返回 `null`（不排程）比把线程卡住好。
const int _maxSteps = 3000;

DateTime? _stepByDays({
  required DateTime anchor,
  required DateTime now,
  required int step,
}) {
  // 先按天数差估算，省掉绝大多数循环。用 `difference` 估出来的值在夏令时
  // 切换日可能差一天，所以后面还要用循环校正 —— 估算只负责「接近」。
  int steps = now.difference(anchor).inDays ~/ step;
  if (steps < 0) steps = 0;

  for (int i = 0; i <= _maxSteps; i++) {
    final DateTime candidate = DateTime(
      anchor.year,
      anchor.month,
      anchor.day + steps * step,
      anchor.hour,
      anchor.minute,
      anchor.second,
    );
    if (candidate.isAfter(now)) return candidate;
    steps++;
  }
  return null;
}

DateTime? _stepByMonths({required DateTime anchor, required DateTime now}) {
  int months = (now.year - anchor.year) * 12 + (now.month - anchor.month);
  if (months < 0) months = 0;

  for (int i = 0; i <= _maxSteps; i++) {
    final DateTime candidate = addMonthsClamped(anchor, months);
    if (candidate.isAfter(now)) return candidate;
    months++;
  }
  return null;
}
