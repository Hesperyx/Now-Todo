import '../models/enums.dart';

/// 一条重复规则。
///
/// 这是存储层 `recurrence_rules` 那一行去掉 `id` / `createdAt` 之后的内容，
/// 也是纯计算与界面之间唯一的交换格式。这里**不依赖 Flutter**：规则的计算
/// 与描述都要能在单元测试里穷举，见 `docs/ARCHITECTURE.md` §5.2。
///
/// 时间字段是**本地时间**（`DateTime` 而非 UTC 毫秒）。存储层存的是 UTC 毫秒，
/// 换算是仓储的事；到了这一层，箭头指向的都是日历上的某一天某一刻。
///
/// ## 不变式
///
/// 构造函数不拦这些——`const` 构造函数里没法对集合做断言，而抛异常会让
/// 「从坏数据里读出一条规则」变成崩溃。计算函数一律**容忍**越界输入
/// （见 `recurrence.dart` 的说明），写入数据库之前由 [normalized] 收口：
///
/// - `interval >= 1`；
/// - `byWeekday` ⊆ 1…7（1 = 周一，与 `DateTime.weekday` 一致）；
/// - `byMonthDay` ⊆ 1…31；
/// - 指定 `byMonthDay` 为 29 / 30 / 31 而目标月份没有那天时，落到该月最后一天。
class RecurrenceRule {
  const RecurrenceRule({
    required this.startsOn,
    this.frequency = RecurrenceFrequency.daily,
    this.interval = 1,
    this.byWeekday = const <int>{},
    this.byMonthDay = const <int>{},
    this.endDate,
    this.endCount,
  });

  /// 系列的第 1 次出现。**这是整个系列的锚点**，后续每一次都从它推算，
  /// 而不是在上一次的结果上继续加点（那样会在短月之后永久漂移）。
  ///
  /// 用户单独改某一条实例的日期时**不动这个值** —— 那正是「仅此一次」
  /// 与「此后全部」的区别所在。
  final DateTime startsOn;

  final RecurrenceFrequency frequency;

  /// 间隔倍数。`weekly` + `2` = 每两周。
  final int interval;

  /// 每周重复时生效：1 = 周一 … 7 = 周日。空集 = 与 [startsOn] 同一星期几。
  final Set<int> byWeekday;

  /// 每月重复时生效：1…31。空集 = 与 [startsOn] 同一号。
  final Set<int> byMonthDay;

  /// 结束日期（本地零点，**含这一天**）。`null` = 这个条件不限。
  final DateTime? endDate;

  /// 最多生成多少条（含第 1 条）。`null` = 这个条件不限。
  ///
  /// 判定的依据是「这个系列现在有几条任务」（`tasks.recurrence_rule_id`
  /// 相同），而不是数到第几次。删掉其中一条历史会让计数少一，系列于是再
  /// 多出一次 —— 这是刻意的取舍：计数规则要能在用户删历史之后仍然自洽，
  /// 代价是多跑一次，而不是静默吞掉一次。
  final int? endCount;

  /// 两个结束条件都没设，会一直重复下去。界面上要显式说出来，
  /// 「永久重复」是个需要用户点头的决定。
  bool get isForever => endDate == null && endCount == null;

  RecurrenceRule copyWith({
    DateTime? startsOn,
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? byWeekday,
    Set<int>? byMonthDay,
    DateTime? endDate,
    int? endCount,
    bool clearEndDate = false,
    bool clearEndCount = false,
  }) => RecurrenceRule(
    startsOn: startsOn ?? this.startsOn,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    byWeekday: byWeekday ?? this.byWeekday,
    byMonthDay: byMonthDay ?? this.byMonthDay,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    endCount: clearEndCount ? null : (endCount ?? this.endCount),
  );

  /// 收口成可以写进数据库的形状：间隔至少 1，星期与号数剔掉越界值。
  ///
  /// 空集合与 `null` 在存储层是同一件事（那一列可空），映射时统一成 `null`。
  RecurrenceRule normalized() => RecurrenceRule(
    startsOn: startsOn,
    frequency: frequency,
    interval: interval < 1 ? 1 : interval,
    byWeekday: byWeekday.where((int d) => d >= 1 && d <= 7).toSet(),
    byMonthDay: byMonthDay.where((int d) => d >= 1 && d <= 31).toSet(),
    endDate: endDate,
    endCount: endCount == null || endCount! < 1 ? null : endCount,
  );

  /// 换频率时把上一个频率专属的字段清掉。
  ///
  /// 不清的话，从「每周一」改成「每月」会留下一个没人看的 `byWeekday`，
  /// 用户再改回每周时它会突然复活 —— 那不是用户以为自己在改的东西。
  RecurrenceRule withFrequency(RecurrenceFrequency next) => RecurrenceRule(
    startsOn: startsOn,
    frequency: next,
    interval: interval,
    byWeekday: next == RecurrenceFrequency.weekly ? byWeekday : const <int>{},
    byMonthDay: next == RecurrenceFrequency.monthly
        ? byMonthDay
        : const <int>{},
    endDate: endDate,
    endCount: endCount,
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.startsOn == startsOn &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.endDate == endDate &&
      other.endCount == endCount &&
      other.byWeekday.length == byWeekday.length &&
      other.byWeekday.containsAll(byWeekday) &&
      other.byMonthDay.length == byMonthDay.length &&
      other.byMonthDay.containsAll(byMonthDay);

  @override
  int get hashCode => Object.hash(
    startsOn,
    frequency,
    interval,
    Object.hashAllUnordered(byWeekday),
    Object.hashAllUnordered(byMonthDay),
    endDate,
    endCount,
  );

  @override
  String toString() =>
      'RecurrenceRule(${frequency.name} × $interval, '
      'weekday=$byWeekday, monthDay=$byMonthDay, '
      'endDate=$endDate, endCount=$endCount)';
}
