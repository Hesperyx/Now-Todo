import '../models/enums.dart';

/// 一次专注计时的完整状态。
///
/// **这个对象里没有任何计时器字段，也不该有。** 已用时长不是「累加」出来的，
/// 而是由三个时刻算出来的：
///
/// ```
/// 已用 = 当前时刻 - 开始时刻 - 累计暂停时长
/// ```
///
/// 为什么非要这么拧着来：
///
/// - `Timer` 在后台与锁屏会被系统压制，累加值必然漂移——用户锁屏半小时回来，
///   看到的是「已专注 3 分钟」。
/// - 进程被系统回收后累加状态直接归零，而时间戳还在数据库里躺着。
///   把 `startedAt` 和 `pausedMillis` 存下来，重新打开应用就能接着算。
///
/// 于是 UI 层只需要每秒拿 `DateTime.now()` 调一次 [elapsed] 重画，
/// 不需要知道任何历史。
class FocusTimerState {
  const FocusTimerState({
    required this.startedAt,
    required this.kind,
    required this.mode,
    this.plan,
    this.pausedMillis = Duration.zero,
    this.pausedAt,
  }) : assert(
         mode == FocusTimerMode.countUp || plan != null,
         '倒计时必须给一个 plan，否则「走满了」无从判断',
       );

  /// 调用方没给 plan 时用的兜底专注时长。
  ///
  /// 产品里的实际时长由用户设置决定，这里只是一个「总要有个起点」的默认值。
  /// 之所以要兜底而不是让断言炸掉：默认模式就是倒计时，一忘传参数就崩在
  /// 用户面前，代价远大于多给一个合理的默认值。
  static const Duration defaultPlan = Duration(minutes: 25);

  /// 开一个新的计时。
  factory FocusTimerState.started({
    required DateTime at,
    FocusSessionKind kind = FocusSessionKind.focus,
    FocusTimerMode mode = FocusTimerMode.countDown,
    Duration? plan,
  }) {
    // 正计时没有终点，带上 plan 只会让 [isFinished] 自相矛盾。
    assert(mode == FocusTimerMode.countDown || plan == null, '正计时不该给 plan');
    return FocusTimerState(
      startedAt: at,
      kind: kind,
      mode: mode,
      plan: mode == FocusTimerMode.countDown ? (plan ?? defaultPlan) : null,
    );
  }

  /// 本次计时的开始时刻。
  ///
  /// 这是个**绝对时刻**，不是墙上时间。跨时区移动不会让它变，用户改系统时钟
  /// 会（这也是 [elapsed] 在算出负数时钳到 0 的原因）。
  final DateTime startedAt;

  /// 这是专注还是休息。
  final FocusSessionKind kind;

  /// 正计时还是倒计时。
  final FocusTimerMode mode;

  /// 计划时长。正计时模式下为 null。
  final Duration? plan;

  /// **已经结束的**暂停累计时长。正在进行的暂停不算在里面——那由
  /// [pausedAt] 单独表示，因为它占用的时长要到恢复时才确定。
  final Duration pausedMillis;

  /// 当前这次暂停的开始时刻。非 null 就表示正暂停着。
  final DateTime? pausedAt;

  /// 计划时长换算成秒，方便落库（`focus_sessions.planned_seconds`）。
  int? get plannedSeconds => plan?.inSeconds;

  /// 现在是否暂停中。
  bool get isPaused => pausedAt != null;

  /// 到 [now] 为止的已用时长。
  ///
  /// 暂停期间它会**冻住**：用户 10 点开始，10 点 5 分暂停，11 点回到应用，
  /// 这里仍然返回 5 分钟，直到恢复计时。
  Duration elapsed(DateTime now) {
    final DateTime reference = pausedAt ?? now;
    final Duration raw = reference.difference(startedAt) - pausedMillis;
    return raw.isNegative ? Duration.zero : raw;
  }

  /// 到 [now] 为止还差多久走满。正计时模式返回 null。
  ///
  /// 可以是负数（走过头了），调用方自己决定怎么显示。
  Duration? remaining(DateTime now) {
    final Duration? target = plan;
    if (target == null) return null;
    return target - elapsed(now);
  }

  /// 倒计时是否已经走满。正计时模式永远返回 false。
  bool isFinished(DateTime now) {
    final Duration? left = remaining(now);
    return left != null && left <= Duration.zero;
  }

  /// 完成进度，0 到 1 之间（可能超过 1，调用方自己夹）。
  ///
  /// 正计时没有分母，返回 null。
  double? progress(DateTime now) {
    final Duration? target = plan;
    if (target == null || target <= Duration.zero) return null;
    return elapsed(now).inMilliseconds / target.inMilliseconds;
  }

  /// 暂停。已经暂停时原样返回。
  FocusTimerState pause(DateTime now) {
    if (isPaused) return this;
    return copyWith(pausedAt: now);
  }

  /// 恢复。没在暂停时原样返回。
  ///
  /// 这次暂停的时长在这里才被折算进 [pausedMillis]。**不能**只把 [pausedAt]
  /// 清空：那样这段时间会凭空算进已用时长。
  FocusTimerState resume(DateTime now) {
    final DateTime? since = pausedAt;
    if (since == null) return this;
    final Duration gap = now.difference(since);
    return copyWith(
      pausedMillis: pausedMillis + (gap.isNegative ? Duration.zero : gap),
      // 必须显式清空：`copyWith` 的 null 是「不改」而不是「置空」，
      // 传 `pausedAt: null` 会把原来那个暂停时刻原封不动留下来。
      clearPausedAt: true,
    );
  }

  FocusTimerState copyWith({
    DateTime? startedAt,
    FocusSessionKind? kind,
    FocusTimerMode? mode,
    Duration? plan,
    Duration? pausedMillis,
    DateTime? pausedAt,
    bool clearPausedAt = false,
  }) {
    return FocusTimerState(
      startedAt: startedAt ?? this.startedAt,
      kind: kind ?? this.kind,
      mode: mode ?? this.mode,
      plan: plan ?? this.plan,
      pausedMillis: pausedMillis ?? this.pausedMillis,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
    );
  }

  @override
  String toString() {
    return 'FocusTimerState(startedAt: $startedAt, kind: ${kind.name}, '
        'mode: ${mode.name}, plan: $plan, pausedMillis: $pausedMillis, '
        'pausedAt: $pausedAt)';
  }
}
