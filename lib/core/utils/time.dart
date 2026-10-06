/// 时间处理的统一约定。
///
/// **存储层永远存 UTC 毫秒时间戳（`int`），不存字符串、不存本地时间。**
/// 原因见 `docs/ARCHITECTURE.md` §5：
///
/// - SQLite 没有原生日期类型，字符串排序会踩时区与格式的双重坑；
/// - 整数比较快，且范围查询（今天 / 本周 / 已逾期）可以直接走索引；
/// - UTC 存储让「用户换时区」不会让历史数据变成乱码——显示时再转本地。
///
/// 唯一的例外是**只精确到日**的截止日期（用户没设具体时刻）：它按
/// 「本地零点」存成 UTC 毫秒。这样日历上的那一天对用户是稳定的，
/// 代价是用户跨时区迁移设备后可能整体偏移一天。首版接受这一点，
/// 见下方 [dayOnlyMillis] 的说明。
library;

extension UtcMillis on DateTime {
  /// 转成存储用的 UTC 毫秒时间戳。
  int get utcMillis => toUtc().millisecondsSinceEpoch;
}

/// 把存储的 UTC 毫秒时间戳还原成**本地时间**，用于显示与日期计算。
DateTime fromUtcMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();

/// 当前时刻的存储值。
int nowUtcMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

/// 本地时区下 [day] 所在那一天的**起点**（本地 00:00:00.000）的存储值。
int startOfLocalDayMillis(DateTime day) {
  final local = day.toLocal();
  return DateTime(local.year, local.month, local.day).utcMillis;
}

/// 本地时区下 [day] 所在那一天的**终点**（次日本地 00:00）的存储值。
///
/// 与 [startOfLocalDayMillis] 组成**左闭右开**区间：
/// `dueDate >= start && dueDate < end`。
/// 不要写成 `<= end`——那会把次日零点的任务算进今天。
int endOfLocalDayMillis(DateTime day) {
  final local = day.toLocal();
  return DateTime(local.year, local.month, local.day + 1).utcMillis;
}

/// 判断两个时间戳是否落在本地时区的同一天。
bool isSameLocalDay(int aUtcMillis, int bUtcMillis) {
  final a = fromUtcMillis(aUtcMillis);
  final b = fromUtcMillis(bUtcMillis);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 把一个只精确到「日」的截止日期规范化成存储值。
///
/// 用户选的是「10 月 8 日」这样一个日历格子，而不是某个时刻。
/// 我们把它固定成本地零点。
///
/// **已知取舍**：用户如果跨时区换设备，本地零点对应的 UTC 瞬间会变，
/// 显示出来的日期可能偏移一天。要用绝对日期（如 `20261008`）存储可以
/// 彻底解决，但那会让「截止日期 + 具体时间」两种形态无法共用一列。
/// 首版选择统一用时间戳，并在导出格式里带上 `dueDateHasTime` 标记，
/// 让导入方知道该按哪种精度理解。
int dayOnlyMillis(DateTime day) => startOfLocalDayMillis(day);

/// 当前时刻是否已过 [dueUtcMillis]。`null` 视为未逾期。
bool isOverdue(int? dueUtcMillis, {int? nowMillis}) {
  if (dueUtcMillis == null) return false;
  return dueUtcMillis < (nowMillis ?? nowUtcMillis());
}

/// 把时间戳格式化成 `2026-10-08`。
String formatDate(int utcMillis) => formatLocalDate(fromUtcMillis(utcMillis));

/// 把一个本地时间格式化成 `2026-10-08`。
///
/// 与 [formatDate] 分开，是因为有些日期本来就没有「UTC 时刻」这回事——
/// 重复规则的结束日期、专注的记账日期都只存在于本地日历上。
String formatLocalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 把时间戳格式化成本地时间 `2026-10-08 09:30`。
String formatDateTime(int utcMillis) {
  final d = fromUtcMillis(utcMillis);
  return '${formatDate(utcMillis)} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// 在 [date] 上推进 [months] 个月，**日期号溢出时夹到目标月的最后一天**。
///
/// 不能直接用 `DateTime(year, month + n, day)`：Dart 会把溢出的日期号顺延
/// 到下个月（`DateTime(2026, 3, 31)` 的「1 月 31 日加 2 个月」会变成 3 月 3 日），
/// 于是一个「每月 31 日」的提醒会在 2 月之后永久跳到 3 日，再也回不来。
/// 用户要的是「每月最后能对上的那天」。
///
/// **注意这是「夹住」而不是「记住原值」**：1 月 31 日加一个月得到 2 月 28 日，
/// 再加一个月得到 3 月 28 日。要回到 31 日，必须始终从**最初那个锚点**上加
/// 整数个月，而不是在上一次的结果上继续加。提醒与重复任务都遵守这条，
/// 调用方别把结果又当成新的锚点。
DateTime addMonthsClamped(DateTime date, int months) {
  final int totalMonths = date.year * 12 + (date.month - 1) + months;
  final int year = totalMonths ~/ 12;
  final int month = totalMonths % 12 + 1;
  // 下个月的第 0 天 = 这个月的最后一天。
  final int lastDay = lastDayOfMonth(year, month);
  return DateTime(
    year,
    month,
    date.day > lastDay ? lastDay : date.day,
    date.hour,
    date.minute,
    date.second,
  );
}

/// [year] 年 [month] 月有多少天。闰年由 `DateTime` 自己算，不手写规则。
int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 在 [date] 上推进 [days] 天，**保留时分秒**。
///
/// `date.add(Duration(days: 1))` 在夏令时切换日会偏离 24 小时，
/// 于是「每天 09:00」会在切换后变成 08:00 或 10:00 并一直保持下去。
/// 这里走的是日历加法，跨过切换日之后仍然是那个钟点。
DateTime addDaysKeepingTime(DateTime date, int days) => DateTime(
  date.year,
  date.month,
  date.day + days,
  date.hour,
  date.minute,
  date.second,
);

/// 把一段时长格式化给用户看。
///
/// 一小时以内是 `25:00` —— 计时器要的是「还剩几分几秒」，`0:25:00` 前面
/// 那个恒为零的小时只会让数字看起来更长。超过一小时才补上小时位，
/// 因为那时候它是有意义的。
///
/// 负数按零处理：倒计时走过头之后界面不该出现 `-00:03`。
String formatDuration(Duration d) {
  final int total = d.isNegative ? 0 : d.inSeconds;
  final int hours = total ~/ 3600;
  final String mm = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final String ss = (total % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$mm:$ss' : '$hours:$mm:$ss';
}

/// 把一段时长写成一句人话：「25 分钟」「1 小时 25 分」。
///
/// 与 [formatDuration] 的分工：那个给计时器用（要精确到秒、要对齐成时钟的样子），
/// 这个给统计用（换算成分钟就够了，`01:25:00` 这种写法在统计里反而要读两遍）。
/// 秒被丢掉而不是四舍五入——统计里的秒数是派生的，凑整只会让人拿计算器去对。
String formatDurationText(Duration d) {
  final int total = d.isNegative ? 0 : d.inSeconds;
  if (total < 60) return total == 0 ? '0 分钟' : '不到 1 分钟';
  final int minutes = total ~/ 60;
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) return '$minutes 分钟';
  return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
}

/// 把秒数写成一句人话，见 [formatDurationText]。
String formatSecondsText(int seconds) =>
    formatDurationText(Duration(seconds: seconds));
