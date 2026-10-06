import '../models/enums.dart';

/// 时长设置的边界。
///
/// 下限不是「技术上跑不了」，而是「低于这个数就不算一段专注」：1 分钟的
/// 番茄钟只会往统计里塞噪声。上限是防手滑 —— 把 25 打成 2500 的人不该得到
/// 一个要跑 41 小时的计时器。
const int minFocusMinutes = 5;
const int maxFocusMinutes = 180;
const int minBreakMinutes = 1;
const int maxBreakMinutes = 60;

/// 某个会话类型允许的时长区间。
({int min, int max}) minutesRangeFor(FocusSessionKind kind) => switch (kind) {
  FocusSessionKind.focus => (min: minFocusMinutes, max: maxFocusMinutes),
  FocusSessionKind.shortBreak => (min: minBreakMinutes, max: maxBreakMinutes),
  FocusSessionKind.longBreak => (min: minBreakMinutes, max: maxBreakMinutes),
};

/// 校验时长，返回给用户看的错误文案；合法时返回 null。
///
/// 返回文案而不是 bool，是因为调用点拿到 bool 之后还得再写一遍同样的分支
/// 去编一句话，那种重复很快就会出现「提示和规则不一致」。
String? validateMinutes(int minutes, FocusSessionKind kind) {
  final ({int min, int max}) range = minutesRangeFor(kind);
  if (minutes < range.min) return '太短了，最少 ${range.min} 分钟。';
  if (minutes > range.max) return '太长了，最多 ${range.max} 分钟。';
  return null;
}

/// 一段专注结束之后该接哪种休息。
///
/// 每 [roundsBeforeLongBreak] 轮专注才给一次长休息。传进来的
/// [completedFocusRounds] 是**含刚结束这一次**的累计轮数：第 4 轮结束该长休息。
/// 轮次配置成 0 或负数时一律给短休息 —— 除零和「永远长休息」都不是用户想要的。
FocusSessionKind breakAfterFocus({
  required int completedFocusRounds,
  required int roundsBeforeLongBreak,
}) {
  if (roundsBeforeLongBreak <= 0) return FocusSessionKind.shortBreak;
  // 0 轮的情况下 `0 % n == 0` 会算出长休息 —— 但要传进来 0 说明这一段的终点
  // 根本不是一段专注，没有理由给长休息。
  if (completedFocusRounds <= 0) return FocusSessionKind.shortBreak;
  return completedFocusRounds % roundsBeforeLongBreak == 0
      ? FocusSessionKind.longBreak
      : FocusSessionKind.shortBreak;
}

/// 一段休息结束之后一律回到专注。
FocusSessionKind kindAfterBreak() => FocusSessionKind.focus;
