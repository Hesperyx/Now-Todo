/// 重复任务的**纯计算**部分：给定一条规则，算出它的第几次出现落在哪一天。
///
/// 只回答日期问题，不碰数据库、不碰 Flutter。单独拆出来的理由与提醒一样
/// （见 `lib/core/notifications/reminder_plan.dart` 的文件头）：跨月、月末、
/// 闰年、指定星期几这些边界是最容易写错的地方，必须是可穷举测试的纯函数。
///
/// ## 三条贯穿全文件的约定
///
/// 1. **一切都从锚点推算。** 第 k 次出现 = `startsOn` 加上 `k × interval`，
///    而不是在上一次的结果上继续加。在结果上累加会让「1 月 31 日」变成
///    2 月 28 日之后就再也回不到 31 日。
/// 2. **容忍脏输入。** `interval` 小于 1 当成 1，星期与号数越界就丢掉。
///    读出一条手改过的坏规则时，用户该看到的是「规则怪怪的」，不是崩溃。
/// 3. **序列严格递增。** 有重复项（比如 `byMonthDay = {30, 31}` 在 2 月
///    双双夹到 28 日）时只保留一个，这样「第一个晚于 X 的候选」可以边找边停。
/// 4. **`endCount` 不在这里判。** 「还剩几次」是这个系列已经生成了几条任务的
///    函数（`tasks.recurrence_rule_id` 的行数），日期序列本身不知道这件事。
///    判次数只在 [nextAfterCompletion] 里做，别处再判一次就会出现两个权威。
library;

import '../models/enums.dart';
import '../utils/time.dart';
import 'recurrence_rule.dart';

/// 一次搜索的上限，单位是「规则的间隔倍数」。
///
/// 与提醒用的是同一个理由：锚点可能在很久以前，估算不准时要靠循环校正。
/// 真跑到上界说明锚点是脏数据（比如 1970 年），这时候返回 `null` 比把
/// 线程卡住好。
const int _maxSteps = 3000;

/// 规则的第 1 次出现。
///
/// 每天 / 每年、以及没有指定星期几的每周、没有指定号数的每月，结果就是
/// [RecurrenceRule.startsOn] 本身。指定了星期几或号数时，取锚点当天或
/// 之后第一个命中的那一天。
///
/// **不判 `endDate`**：规则自相矛盾（结束日期早于开始）时，界面要能把这条
/// 规则原样显示出来。判定「还有没有下一次」是 [occurrenceAfter] 的事。
DateTime firstOccurrence(RecurrenceRule rule) => _occurrences(rule).first;

/// 严格晚于 [after] 的下一次出现。系列已经结束（落在 `endDate` 之后）时返回 `null`。
///
/// 不判 `endCount`：见文件头的第 4 条约定。
DateTime? occurrenceAfter(RecurrenceRule rule, DateTime after) {
  for (final DateTime candidate in _occurrences(
    rule,
    fromBlock: _estimateBlock(rule, after),
  )) {
    if (!candidate.isAfter(after)) continue;
    return _beyondEnd(rule, candidate) ? null : candidate;
  }
  return null;
}

/// 不晚于 [date] 的最后一次出现。锚点都晚于 [date] 时返回 `null`。
///
/// 用途是**把一条被单独改过日期的实例吸回规则自身的节奏**：某条任务被
/// 挪到下周三，不代表「每周一」这个系列从此改成周三。找到它在原本节奏里
/// 对应的那一次，再从那里往后推，系列就还是原来的系列。
DateTime? occurrenceOnOrBefore(RecurrenceRule rule, DateTime date) {
  DateTime? last;
  for (final DateTime candidate in _occurrences(
    rule,
    fromBlock: _estimateBlock(rule, date),
  )) {
    if (candidate.isAfter(date)) break;
    last = candidate;
  }
  return last;
}

/// 这一条完成后，下一条的日期定在哪天。系列已经跑完则返回 `null`。
///
/// [instanceDate] 是刚完成的那一条任务自己的日期；[seriesCount] 是这个系列
/// 已经生成了多少条（**含刚完成的这条**）；[notBefore] 是新任务允许的最早
/// 时刻——只精确到日的任务传「今天零点」，带时刻的传「现在」。
///
/// 拖了很久才完成时，按节奏推出来的那几天可能都已经过去了，这里会一路往后
/// 跳到第一个还没过掉的日子。**新建出来就已经逾期的新任务不是提醒，是噪音。**
DateTime? nextAfterCompletion({
  required RecurrenceRule rule,
  required DateTime instanceDate,
  required DateTime notBefore,
  required int seriesCount,
}) {
  final int? limit = rule.endCount;
  if (limit != null && seriesCount >= limit) return null;

  final DateTime snap =
      occurrenceOnOrBefore(rule, instanceDate) ?? firstOccurrence(rule);
  DateTime? next = occurrenceAfter(rule, snap);
  while (next != null && next.isBefore(notBefore)) {
    next = occurrenceAfter(rule, next);
  }
  return next;
}

/// [candidate] 是否已经落在规则的结束日期之后。结束日期**含当天**：
/// 那天本身照常出现，第二天起才没有下一次。
bool _beyondEnd(RecurrenceRule rule, DateTime candidate) {
  final DateTime? end = rule.endDate;
  if (end == null) return false;
  final DateTime day = DateTime(candidate.year, candidate.month, candidate.day);
  final DateTime limit = DateTime(end.year, end.month, end.day);
  return day.isAfter(limit);
}

/// 规则的第 [fromBlock] 个间隔块起的全部出现，按时间递增。
///
/// 每周指定了星期几、每月指定了号数时，一个「块」里会有多个候选（块内的
/// 日期按时间排好序），其余频率一个块就是一个候选。
Iterable<DateTime> _occurrences(
  RecurrenceRule rule, {
  int fromBlock = 0,
}) sync* {
  final DateTime anchor = rule.startsOn;
  final int interval = rule.interval < 1 ? 1 : rule.interval;
  final int start = fromBlock < 0 ? 0 : fromBlock;
  DateTime? previous;

  /// 序列必须严格递增：夹到月末的号数会撞车（2 月的 30 与 31 都是 28 日）。
  bool fresh(DateTime candidate) {
    if (previous != null && !candidate.isAfter(previous!)) return false;
    previous = candidate;
    return true;
  }

  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      for (int k = start; k < start + _maxSteps; k++) {
        final DateTime candidate = addDaysKeepingTime(anchor, k * interval);
        if (fresh(candidate)) yield candidate;
      }

    case RecurrenceFrequency.weekly:
      final List<int> weekdays = _sortedInRange(rule.byWeekday, 7);
      if (weekdays.isEmpty) {
        for (int k = start; k < start + _maxSteps; k++) {
          final DateTime candidate = addDaysKeepingTime(
            anchor,
            k * interval * 7,
          );
          if (fresh(candidate)) yield candidate;
        }
        return;
      }
      for (int k = start; k < start + _maxSteps; k++) {
        for (final int weekday in weekdays) {
          final DateTime candidate = addDaysKeepingTime(
            anchor,
            weekday - anchor.weekday + k * 7 * interval,
          );
          // 第 0 块里排在锚点前面的那几天不属于这个系列：系列从锚点开始。
          if (candidate.isBefore(anchor)) continue;
          if (fresh(candidate)) yield candidate;
        }
      }

    case RecurrenceFrequency.monthly:
      final List<int> monthDays = _sortedInRange(rule.byMonthDay, 31);
      for (int k = start; k < start + _maxSteps; k++) {
        final int months = k * interval;
        if (monthDays.isEmpty) {
          final DateTime candidate = addMonthsClamped(anchor, months);
          if (fresh(candidate)) yield candidate;
          continue;
        }
        final int total = anchor.year * 12 + (anchor.month - 1) + months;
        final int year = total ~/ 12;
        final int month = total % 12 + 1;
        final int lastDay = lastDayOfMonth(year, month);
        for (final int day in monthDays) {
          final DateTime candidate = DateTime(
            year,
            month,
            day > lastDay ? lastDay : day,
            anchor.hour,
            anchor.minute,
            anchor.second,
          );
          if (candidate.isBefore(anchor)) continue;
          if (fresh(candidate)) yield candidate;
        }
      }

    case RecurrenceFrequency.yearly:
      for (int k = start; k < start + _maxSteps; k++) {
        final DateTime candidate = addMonthsClamped(anchor, k * interval * 12);
        if (fresh(candidate)) yield candidate;
      }
  }
}

/// 集合里的合法值，升序。越界的丢掉而不是夹住：`0` 或 `8` 不是「星期八」，
/// 那是写坏了的数字，猜它的意思只会把错误藏起来。
List<int> _sortedInRange(Set<int> values, int max) {
  final List<int> result = values
      .where((int value) => value >= 1 && value <= max)
      .toList();
  result.sort();
  return result;
}

/// 从 [target] 反推「大概在第几块」，用来跳过绝大多数循环。
///
/// 估低两块再开始找：估算只负责「接近」，真正判定靠后面的逐块比较。
/// 估高了也不会漏（序列递增，最后一个不晚于目标的候选一定在这附近），
/// 但估低了会让循环白跑 —— 所以宁可低估。
int _estimateBlock(RecurrenceRule rule, DateTime target) {
  final DateTime anchor = rule.startsOn;
  final int interval = rule.interval < 1 ? 1 : rule.interval;
  final int days = target.difference(anchor).inDays;
  final int months =
      (target.year - anchor.year) * 12 + (target.month - anchor.month);

  final int raw;
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      raw = days ~/ interval;
    case RecurrenceFrequency.weekly:
      raw = days ~/ (7 * interval);
    case RecurrenceFrequency.monthly:
      raw = months ~/ interval;
    case RecurrenceFrequency.yearly:
      raw = months ~/ (12 * interval);
  }
  final int back = raw - 2;
  return back < 0 ? 0 : back;
}
