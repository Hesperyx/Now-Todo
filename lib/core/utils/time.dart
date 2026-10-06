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
String formatDate(int utcMillis) {
  final d = fromUtcMillis(utcMillis);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 把时间戳格式化成本地时间 `2026-10-08 09:30`。
String formatDateTime(int utcMillis) {
  final d = fromUtcMillis(utcMillis);
  return '${formatDate(utcMillis)} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
