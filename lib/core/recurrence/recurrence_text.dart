import '../models/enums.dart';
import '../utils/time.dart';
import 'recurrence.dart';
import 'recurrence_rule.dart';

/// 把重复规则说成一句人话。
///
/// 与提醒的 `buildReminderContent` 是同一类东西：纯函数，只拼字符串。
/// 规则在界面上是一堆开关和数字，用户真正能确认的只有「这句话读起来是不是
/// 我想要的」，所以这句话必须有测试盯着——月末、闰年、按次数结束这几处
/// 恰好都是用户自己也不容易心算的。
///
/// 文案里刻意带上会被用户当成坑的后果：选了 31 日就写明短月落在月末，
/// 选了 2 月 29 日就写明平年落在 28 日。**宁可啰嗦，也不要让用户在 2 月
/// 底看到一次没预期的提醒。**
String describeRecurrence(RecurrenceRule rule) {
  final int interval = rule.interval < 1 ? 1 : rule.interval;
  return '${_describeCore(rule, interval)}${_describeEnd(rule)}';
}

/// 下一次出现的日期，`2026-10-08`。系列已经跑完时返回 `null`。
String? nextOccurrenceText(RecurrenceRule rule, {required DateTime now}) {
  final DateTime? next = occurrenceAfter(rule, now);
  return next == null ? null : formatLocalDate(next);
}

/// 规则的核心部分，不含结束条件。
String _describeCore(RecurrenceRule rule, int interval) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return interval == 1 ? '每天' : '每 $interval 天';

    case RecurrenceFrequency.weekly:
      final List<int> weekdays = _sortedInRange(rule.byWeekday, 7);
      if (weekdays.isEmpty) {
        final String day = _weekdayName(rule.startsOn.weekday);
        return interval == 1 ? '每周$day' : '每 $interval 周的周$day';
      }
      final String days = weekdays.map(_weekdayName).join('、');
      return interval == 1 ? '每周$days' : '每 $interval 周的周$days';

    case RecurrenceFrequency.monthly:
      // 「每 2 个月」而不是「每 2 月」：后者读起来像在说二月份。
      final String base = interval == 1 ? '每月' : '每 $interval 个月';
      final List<int> picked = _sortedInRange(rule.byMonthDay, 31);
      // 没挑号数时按锚点的号数走，提示照样要给：锚点在 31 日同样会遇到短月。
      final List<int> days = picked.isEmpty ? <int>[rule.startsOn.day] : picked;
      return '$base ${days.join('、')} 日${_shortMonthHint(days)}';

    case RecurrenceFrequency.yearly:
      final String base = interval == 1 ? '每年' : '每 $interval 年的';
      final String date = '${rule.startsOn.month} 月 ${rule.startsOn.day} 日';
      return '$base $date${_leapDayHint(rule.startsOn)}';
  }
}

/// 结束条件，接在上面那句话后面。
String _describeEnd(RecurrenceRule rule) {
  final StringBuffer buffer = StringBuffer();
  final DateTime? end = rule.endDate;
  if (end != null) buffer.write('，到 ${formatLocalDate(end)} 结束');
  final int? count = rule.endCount;
  if (count != null) buffer.write('，共 $count 次');
  return buffer.toString();
}

/// 选了 29 日以后就要说清短月怎么办。
String _shortMonthHint(List<int> days) =>
    days.any((int day) => day >= 29) ? '（短月落在月末）' : '';

/// 2 月 29 日只在闰年存在。
///
/// 不加这句的话，「每年 2 月 29 日」在三个平年里显示的都是 2 月 28 日，
/// 而用户以为自己设的是那个稀有的日子。
String _leapDayHint(DateTime anchor) =>
    anchor.month == 2 && anchor.day == 29 ? '（平年落在 2 月 28 日）' : '';

String _weekdayName(int weekday) => _weekdayNames[weekday - 1];

/// 与 `DateTime.weekday` 同一套编码：1=周一…7=周日。
const List<String> _weekdayNames = <String>['一', '二', '三', '四', '五', '六', '日'];

List<int> _sortedInRange(Set<int> values, int max) {
  final List<int> result = values
      .where((int value) => value >= 1 && value <= max)
      .toList();
  result.sort();
  return result;
}
