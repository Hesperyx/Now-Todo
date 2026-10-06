import '../focus/focus_timer.dart';
import '../utils/time.dart';
import 'enums.dart';

/// 领域实体。
///
/// 这些类**不依赖 Drift**，也不依赖 Flutter。`features/` 下的界面代码
/// 只认识它们，从来看不到生成的 `TasksData` / `TasksCompanion`。
/// 这条边界由 `docs/ARCHITECTURE.md` §3 规定，好处是：
///
/// - 改数据库结构时，编译错误会精确指向需要改的映射代码，而不是散落到 UI；
/// - Widget 测试可以直接构造实体，不需要起一个数据库；
/// - `Nullable` 的 `Value<T>` 包装不会漏进界面层。
///
/// 所有时间字段都是 **UTC 毫秒时间戳**，见 `lib/core/utils/time.dart`。
/// 界面上要显示时再转本地时间，不要在实体里存格式化好的字符串。

/// 一条任务。
class TodoTask {
  const TodoTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.dueDate,
    this.dueDateHasTime = false,
    this.priority = TaskPriority.none,
    this.status = TaskStatus.pending,
    this.listId,
    this.recurrenceRuleId,
    this.completedAt,
    this.estimatedPomodoros,
    this.subtaskTotal = 0,
    this.subtaskDone = 0,
    this.tagNames = const <String>[],
  });

  final String id;
  final String title;
  final String? note;

  /// 截止时间（UTC 毫秒）。`null` = 没有截止日期。
  final int? dueDate;

  /// [dueDate] 是否精确到时刻。见 `Tasks.dueDateHasTime` 的说明。
  final bool dueDateHasTime;

  final TaskPriority priority;
  final TaskStatus status;
  final String? listId;
  final String? recurrenceRuleId;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;

  /// 预估要花几个番茄钟。`null` = 没估过，与「估了 0 个」不同。
  final int? estimatedPomodoros;

  /// 子任务总数。由查询时的聚合子查询算出，不是表里的列。
  final int subtaskTotal;

  /// 已完成的子任务数。
  final int subtaskDone;

  /// 标签名。首版只读展示，编辑走 `TaskRepository.setTags`。
  final List<String> tagNames;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isRepeating => recurrenceRuleId != null;

  /// 是否已过截止时间。[nowMillis] 由调用方传入，
  /// 这样同一帧里渲染一堆任务时用的是同一个「现在」，也方便测试。
  bool isOverdue(int nowMillis) {
    final int? due = dueDate;
    if (due == null || isCompleted) return false;
    return due < nowMillis;
  }

  /// 是否在本地时间的「今天」到期。
  bool isDueToday(int nowMillis) {
    final int? due = dueDate;
    if (due == null) return false;
    final DateTime a = DateTime.fromMillisecondsSinceEpoch(
      due,
      isUtc: true,
    ).toLocal();
    final DateTime b = DateTime.fromMillisecondsSinceEpoch(
      nowMillis,
      isUtc: true,
    ).toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  TodoTask copyWith({
    String? title,
    Object? note = _unset,
    Object? dueDate = _unset,
    bool? dueDateHasTime,
    TaskPriority? priority,
    TaskStatus? status,
    Object? listId = _unset,
    Object? recurrenceRuleId = _unset,
    Object? completedAt = _unset,
    Object? estimatedPomodoros = _unset,
    int? subtaskTotal,
    int? subtaskDone,
    List<String>? tagNames,
  }) {
    return TodoTask(
      id: id,
      title: title ?? this.title,
      note: note == _unset ? this.note : note as String?,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as int?,
      dueDateHasTime: dueDateHasTime ?? this.dueDateHasTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      listId: listId == _unset ? this.listId : listId as String?,
      recurrenceRuleId: recurrenceRuleId == _unset
          ? this.recurrenceRuleId
          : recurrenceRuleId as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as int?,
      estimatedPomodoros: estimatedPomodoros == _unset
          ? this.estimatedPomodoros
          : estimatedPomodoros as int?,
      subtaskTotal: subtaskTotal ?? this.subtaskTotal,
      subtaskDone: subtaskDone ?? this.subtaskDone,
      tagNames: tagNames ?? this.tagNames,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoTask &&
      other.id == id &&
      other.title == title &&
      other.note == note &&
      other.dueDate == dueDate &&
      other.dueDateHasTime == dueDateHasTime &&
      other.priority == priority &&
      other.status == status &&
      other.listId == listId &&
      other.recurrenceRuleId == recurrenceRuleId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt &&
      other.estimatedPomodoros == estimatedPomodoros &&
      other.subtaskTotal == subtaskTotal &&
      other.subtaskDone == subtaskDone &&
      _sameNames(other.tagNames, tagNames);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    note,
    dueDate,
    dueDateHasTime,
    priority,
    status,
    listId,
    recurrenceRuleId,
    createdAt,
    updatedAt,
    completedAt,
    estimatedPomodoros,
    subtaskTotal,
    subtaskDone,
    Object.hashAll(tagNames),
  );

  @override
  String toString() => 'TodoTask($id, "$title", $status)';

  static bool _sameNames(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// `copyWith` 里用来区分「不传」和「显式传 null」的哨兵。
///
/// 没有它就没办法把 `note` 改回 `null`——`copyWith(note: null)` 会被
/// 当成「不改这个字段」。这是 Dart 里手写不可变对象的老问题。
const Object _unset = Object();

/// 子任务。
class TodoSubtask {
  const TodoSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.createdAt,
    this.isDone = false,
    this.sortOrder = 0,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int sortOrder;
  final int createdAt;

  TodoSubtask copyWith({String? title, bool? isDone, int? sortOrder}) =>
      TodoSubtask(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}

/// 清单。
class TodoList {
  const TodoList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    this.pendingCount = 0,
  });

  final String id;
  final String name;

  /// ARGB。`null` = 不用颜色区分。
  final int? color;

  /// 内置清单不可删除。
  final bool isBuiltIn;

  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  /// 未完成任务数。聚合算出来的，不是表里的列。
  final int pendingCount;

  TodoList copyWith({
    String? name,
    Object? color = _unset,
    int? sortOrder,
    int? pendingCount,
  }) => TodoList(
    id: id,
    name: name ?? this.name,
    color: color == _unset ? this.color : color as int?,
    isBuiltIn: isBuiltIn,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pendingCount: pendingCount ?? this.pendingCount,
  );
}

/// 标签。
class TodoTag {
  const TodoTag({
    required this.id,
    required this.name,
    required this.createdAt,
    this.color,
    this.taskCount = 0,
  });

  final String id;
  final String name;
  final int? color;
  final int createdAt;
  final int taskCount;
}

/// 一条本地提醒。
///
/// 与 `Reminders` 表一一对应。`remindAt` 是**首次**触发时刻；重复提醒的
/// 「下一次」不存在这里，而是每次排程时由
/// `lib/core/notifications/reminder_plan.dart` 的 `nextOccurrence` 现算——
/// 存了就会和规则不一致（改了规则忘了改缓存，是这类应用最经典的一类 bug）。
class TodoReminder {
  const TodoReminder({
    required this.id,
    required this.taskId,
    required this.remindAt,
    required this.createdAt,
    this.repeatType = ReminderRepeatType.once,
    this.enabled = true,
  });

  final String id;
  final String taskId;

  /// 首次触发时刻，UTC 毫秒。
  final int remindAt;

  final ReminderRepeatType repeatType;

  /// 关掉后不排程，但记录保留——重新打开就能用，不用重新设一遍。
  final bool enabled;

  final int createdAt;

  TodoReminder copyWith({
    int? remindAt,
    ReminderRepeatType? repeatType,
    bool? enabled,
  }) => TodoReminder(
    id: id,
    taskId: taskId,
    remindAt: remindAt ?? this.remindAt,
    repeatType: repeatType ?? this.repeatType,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoReminder &&
          other.id == id &&
          other.taskId == taskId &&
          other.remindAt == remindAt &&
          other.repeatType == repeatType &&
          other.enabled == enabled &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, taskId, remindAt, repeatType, enabled, createdAt);

  @override
  String toString() =>
      'TodoReminder(id: $id, taskId: $taskId, remindAt: $remindAt, '
      'repeatType: ${repeatType.name}, enabled: $enabled)';
}

/// 一次专注 / 休息会话。
///
/// 与 `FocusTimerState` 是**两件事**：那个是「正在跑的计时」，这个是「已经
/// 记下来的一段历史」。`endedAt == null` 时两者描述同一段时间，会话结束
/// （或用户中途离开）之后就只剩这个了。
class TodoFocusSession {
  const TodoFocusSession({
    required this.id,
    required this.startedAt,
    required this.logicalDate,
    this.taskId,
    this.endedAt,
    this.pausedMillis = 0,
    this.pausedAt,
    this.plannedSeconds,
    this.actualSeconds = 0,
    this.kind = FocusSessionKind.focus,
    this.timerMode = FocusTimerMode.countDown,
    this.completed = false,
    this.note,
  });

  final String id;

  /// 归属任务。`null` = 自由专注，或者原任务已被删除（`ON DELETE SET NULL`）。
  final String? taskId;

  /// 开始时刻（UTC 毫秒）。
  final int startedAt;

  /// 结束时刻。`null` = 还在进行中。
  final int? endedAt;

  /// 已经结束的暂停累计（毫秒）。
  final int pausedMillis;

  /// 当前这次暂停的开始时刻（UTC 毫秒）。非空 = 正暂停着。
  final int? pausedAt;

  /// 计划时长（秒）。正计时为 `null`。
  final int? plannedSeconds;

  /// 实际时长（秒），不含暂停。
  final int actualSeconds;

  final FocusSessionKind kind;
  final FocusTimerMode timerMode;

  /// 归属逻辑日（本地零点毫秒），写入时冻结。
  final int logicalDate;

  /// 是否走满了计划时长。
  final bool completed;

  /// 这一笔的备注，会话结束后补填。
  final String? note;

  /// 还在跑。
  bool get isRunning => endedAt == null;

  bool get isPaused => pausedAt != null;

  /// 这一笔占用的秒数。
  ///
  /// 还没结束的会话 `actualSeconds` 是 0（暂停或结束那一刻才会写上），
  /// 所以统计「今天专注了多久」时要用 [now] 现算一次，否则正在跑的那段
  /// 在界面上永远是 0，直到用户点结束才会突然跳上来。
  int elapsedSeconds(DateTime now) =>
      isRunning ? toTimerState().elapsed(now).inSeconds : actualSeconds;

  /// 还原成计时内核的状态，让 `pause` / `resume` / `elapsed` 只有一份实现。
  ///
  /// 注意：倒计时的行必须能还原出 `plannedSeconds`，否则 `FocusTimerState`
  /// 的断言会当场炸——这是刻意的，静默按「没有终点」处理会算错完成判定。
  FocusTimerState toTimerState() => FocusTimerState(
    startedAt: fromUtcMillis(startedAt),
    kind: kind,
    mode: timerMode,
    plan: plannedSeconds == null ? null : Duration(seconds: plannedSeconds!),
    pausedMillis: Duration(milliseconds: pausedMillis),
    pausedAt: pausedAt == null ? null : fromUtcMillis(pausedAt!),
  );

  TodoFocusSession copyWith({
    Object? taskId = _unset,
    Object? endedAt = _unset,
    int? pausedMillis,
    Object? pausedAt = _unset,
    Object? plannedSeconds = _unset,
    int? actualSeconds,
    FocusSessionKind? kind,
    FocusTimerMode? timerMode,
    int? logicalDate,
    bool? completed,
    Object? note = _unset,
  }) => TodoFocusSession(
    id: id,
    taskId: taskId == _unset ? this.taskId : taskId as String?,
    startedAt: startedAt,
    endedAt: endedAt == _unset ? this.endedAt : endedAt as int?,
    pausedMillis: pausedMillis ?? this.pausedMillis,
    pausedAt: pausedAt == _unset ? this.pausedAt : pausedAt as int?,
    plannedSeconds: plannedSeconds == _unset
        ? this.plannedSeconds
        : plannedSeconds as int?,
    actualSeconds: actualSeconds ?? this.actualSeconds,
    kind: kind ?? this.kind,
    timerMode: timerMode ?? this.timerMode,
    logicalDate: logicalDate ?? this.logicalDate,
    completed: completed ?? this.completed,
    note: note == _unset ? this.note : note as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoFocusSession &&
          other.id == id &&
          other.taskId == taskId &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.pausedMillis == pausedMillis &&
          other.pausedAt == pausedAt &&
          other.plannedSeconds == plannedSeconds &&
          other.actualSeconds == actualSeconds &&
          other.kind == kind &&
          other.timerMode == timerMode &&
          other.logicalDate == logicalDate &&
          other.completed == completed &&
          other.note == note;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    startedAt,
    endedAt,
    pausedMillis,
    pausedAt,
    plannedSeconds,
    actualSeconds,
    kind,
    timerMode,
    logicalDate,
    completed,
    note,
  );

  @override
  String toString() =>
      'TodoFocusSession(id: $id, taskId: $taskId, startedAt: $startedAt, '
      'endedAt: $endedAt, actualSeconds: $actualSeconds, '
      'kind: ${kind.name}, completed: $completed)';
}

/// 用户偏好。与 `AppSettings` 表一一对应，不含 `id` 这类存储细节。
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeModeSetting.system,
    this.defaultView = DefaultView.today,
    this.notificationsEnabled = true,
    this.strongReminders = false,
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsBeforeLongBreak = 4,
    this.autoStartNext = false,
    this.defaultTimerMode = FocusTimerMode.countDown,
    this.midnightMode = false,
    this.midnightEndHour = 4,
    this.initializedAt,
  });

  final ThemeModeSetting themeMode;
  final DefaultView defaultView;
  final bool notificationsEnabled;

  /// 强提醒：到点后持续响铃直到用户处理掉通知。默认关，见 `AppSettings`。
  final bool strongReminders;

  // ────────────────────────── 专注计时 ──────────────────────────

  /// 一轮专注的分钟数。
  final int focusMinutes;

  /// 短休息的分钟数。
  final int shortBreakMinutes;

  /// 长休息的分钟数。
  final int longBreakMinutes;

  /// 几轮专注之后接一次长休息。
  final int roundsBeforeLongBreak;

  /// 一轮结束后是否自动开始下一轮。默认关，见 `AppSettings`。
  final bool autoStartNext;

  /// 新会话默认用哪种计时模式。
  final FocusTimerMode defaultTimerMode;

  /// 午夜模式：凌晨开始的会话算作前一天。默认关。
  final bool midnightMode;

  /// 午夜模式的边界小时，默认 4 点。
  final int midnightEndHour;

  /// 按 [kind] 取对应的时长（分钟）。
  ///
  /// 放在这里而不是每个调用点自己 `switch`：长休息轮次之类的新参数加进来时，
  /// 只需要改这一处。
  int minutesFor(FocusSessionKind kind) => switch (kind) {
    FocusSessionKind.focus => focusMinutes,
    FocusSessionKind.shortBreak => shortBreakMinutes,
    FocusSessionKind.longBreak => longBreakMinutes,
  };

  final int? initializedAt;

  /// 12 项是不是都还是默认值——也就是「用户从没改过设置」。
  ///
  /// 合并导入时用来判断要不要接受文件里的设置：本机改过就不动它的主题、专注时长，
  /// 要连设置一起搬得走覆盖导入（见 `BackupRepository.importData`）。
  /// 不看 [initializedAt]：那是设备的记账时间，第一次启动就会被写上。
  bool get isDefault {
    const AppPreferences defaults = AppPreferences();
    return themeMode == defaults.themeMode &&
        defaultView == defaults.defaultView &&
        notificationsEnabled == defaults.notificationsEnabled &&
        strongReminders == defaults.strongReminders &&
        focusMinutes == defaults.focusMinutes &&
        shortBreakMinutes == defaults.shortBreakMinutes &&
        longBreakMinutes == defaults.longBreakMinutes &&
        roundsBeforeLongBreak == defaults.roundsBeforeLongBreak &&
        autoStartNext == defaults.autoStartNext &&
        defaultTimerMode == defaults.defaultTimerMode &&
        midnightMode == defaults.midnightMode &&
        midnightEndHour == defaults.midnightEndHour;
  }

  AppPreferences copyWith({
    ThemeModeSetting? themeMode,
    DefaultView? defaultView,
    bool? notificationsEnabled,
    bool? strongReminders,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    bool? autoStartNext,
    FocusTimerMode? defaultTimerMode,
    bool? midnightMode,
    int? midnightEndHour,
    int? initializedAt,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    defaultView: defaultView ?? this.defaultView,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    strongReminders: strongReminders ?? this.strongReminders,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    roundsBeforeLongBreak: roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
    autoStartNext: autoStartNext ?? this.autoStartNext,
    defaultTimerMode: defaultTimerMode ?? this.defaultTimerMode,
    midnightMode: midnightMode ?? this.midnightMode,
    midnightEndHour: midnightEndHour ?? this.midnightEndHour,
    initializedAt: initializedAt ?? this.initializedAt,
  );
}
