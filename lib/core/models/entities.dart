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

/// 用户偏好。与 `AppSettings` 表一一对应，不含 `id` 这类存储细节。
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeModeSetting.system,
    this.defaultView = DefaultView.today,
    this.notificationsEnabled = true,
    this.initializedAt,
  });

  final ThemeModeSetting themeMode;
  final DefaultView defaultView;
  final bool notificationsEnabled;
  final int? initializedAt;

  AppPreferences copyWith({
    ThemeModeSetting? themeMode,
    DefaultView? defaultView,
    bool? notificationsEnabled,
    int? initializedAt,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    defaultView: defaultView ?? this.defaultView,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    initializedAt: initializedAt ?? this.initializedAt,
  );
}
