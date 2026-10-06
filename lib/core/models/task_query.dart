import 'enums.dart';

/// 任务列表的排序方式。
enum TaskSort {
  /// 有截止日期的排前面，按时间升序；没有的排后面，按创建时间倒序。
  /// 这是默认值，也是「今天该做什么」最自然的顺序。
  dueDate,

  /// 优先级从高到低，同级按截止日期。
  priority,

  /// 最近创建的在前。
  createdAt,

  /// 按标题的字典序。
  title,
}

/// 一次任务查询的全部条件。
///
/// 用一个不可变的查询对象而不是给 `watchTasks` 堆十个可选参数：
/// 参数一多就没人记得清默认值，而 `copyWith` 链式写法在调用处一眼看得懂。
class TaskQuery {
  const TaskQuery({
    this.showCompleted = false,
    this.dueTodayOnly = false,
    this.overdueOnly = false,
    this.listId,
    this.tagName,
    this.searchText,
    this.priorities = const <TaskPriority>{},
    this.sort = TaskSort.dueDate,
  });

  /// 是否在结果里包含已完成的任务。
  ///
  /// 默认 `false`：待办应用的主列表里混着已经划掉的东西，只会让视线变脏。
  final bool showCompleted;

  /// 只看今天到期的。
  final bool dueTodayOnly;

  /// 只看已逾期的。
  final bool overdueOnly;

  /// 限定清单。`null` = 不限。
  final String? listId;

  /// 限定标签（按标签名，大小写不敏感）。`null` = 不限。
  final String? tagName;

  /// 标题 / 备注的关键字，大小写不敏感。空白串视为不限。
  final String? searchText;

  /// 限定优先级。空集合 = 不限。
  final Set<TaskPriority> priorities;

  final TaskSort sort;

  /// 归一化后的搜索词：去首尾空白，空串变 `null`。
  String? get normalizedSearch {
    final String? raw = searchText;
    if (raw == null) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 除了顶层视图（今天 / 全部 / 已完成）之外，还额外限定了什么。
  ///
  /// 空列表有两种空法：「本来就没有任务」和「条件把它们藏起来了」，
  /// 界面得能分清这两者——所以这个判断只有一份实现，放在这里。
  /// 页面各自算一遍的话，早晚会有人漏掉新增的那个条件，
  /// 于是空列表会理直气壮地说「这里很干净」。
  bool get hasFilters =>
      normalizedSearch != null ||
      listId != null ||
      tagName != null ||
      overdueOnly ||
      priorities.isNotEmpty;

  /// 正在生效的筛选条件条数，用来给筛选入口挂一个小角标。
  int get filterCount {
    int count = 0;
    if (normalizedSearch != null) count++;
    if (listId != null) count++;
    if (tagName != null) count++;
    if (overdueOnly) count++;
    if (priorities.isNotEmpty) count++;
    return count;
  }

  TaskQuery copyWith({
    bool? showCompleted,
    bool? dueTodayOnly,
    bool? overdueOnly,
    Object? listId = _unsetQuery,
    Object? tagName = _unsetQuery,
    Object? searchText = _unsetQuery,
    Set<TaskPriority>? priorities,
    TaskSort? sort,
  }) {
    return TaskQuery(
      showCompleted: showCompleted ?? this.showCompleted,
      dueTodayOnly: dueTodayOnly ?? this.dueTodayOnly,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      listId: listId == _unsetQuery ? this.listId : listId as String?,
      tagName: tagName == _unsetQuery ? this.tagName : tagName as String?,
      searchText: searchText == _unsetQuery
          ? this.searchText
          : searchText as String?,
      priorities: priorities ?? this.priorities,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskQuery &&
      other.showCompleted == showCompleted &&
      other.dueTodayOnly == dueTodayOnly &&
      other.overdueOnly == overdueOnly &&
      other.listId == listId &&
      other.tagName == tagName &&
      other.searchText == searchText &&
      other.sort == sort &&
      other.priorities.length == priorities.length &&
      other.priorities.containsAll(priorities);

  @override
  int get hashCode => Object.hash(
    showCompleted,
    dueTodayOnly,
    overdueOnly,
    listId,
    tagName,
    searchText,
    sort,
    Object.hashAllUnordered(priorities),
  );
}

const Object _unsetQuery = Object();
