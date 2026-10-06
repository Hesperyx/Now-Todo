/// 备份文件的**数据形状**。
///
/// 这一层只认识 Dart：不 import Flutter，也不 import Drift。它和
/// `lib/core/models/entities.dart` 里的领域模型是两套东西——领域模型是
/// 「界面上要用的样子」（`TodoTask` 上挂着子任务数量这种派生字段），
/// 这里的行类型是「文件里要写的样子」（一列不少、一列不多，与表结构一一对应）。
///
/// 分成两份的代价是多写一遍字段清单，收益是：改表结构时编译器会指着这里说
/// 漏了哪一列，而不是等到用户导入别人的备份时才发现某张表少写了一列。
library;

import '../models/entities.dart';

/// 备份格式版本。
///
/// 与 `AppDatabase.schemaVersion`（数据库结构版本）是两件事：库里加一列
/// 不一定动文件格式，文件格式变了也不一定动库。改字段含义、加必填字段时
/// 把它加一，并在 `backup_codec.dart` 的升级链里写一条对应的规则。
const int kExportVersion = 1;

/// 文件里的一个应用信息块。纯记录，导入时不看它——版本判断走
/// `exportVersion`，`schemaVersion` 只用来在出问题时说清「这份文件是哪来的」。
class BackupAppInfo {
  const BackupAppInfo({
    required this.name,
    required this.version,
    required this.schemaVersion,
  });

  /// 应用标识（`AppConstants.databaseName`），不是显示名。
  final String name;

  /// 打包时的版本号。开发机上可能是空的。
  final String version;

  /// 导出时的数据库结构版本。
  final int schemaVersion;

  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'version': version,
    'schemaVersion': schemaVersion,
  };
}

/// 一份备份的全部内容。
///
/// `settings` 直接复用 `AppPreferences`：它就是「十二项用户设置」这件事本身，
/// 再包一个只换名字的类只会多一处要同步的地方。文件里不写 `initializedAt`
/// （那是设备自己的记账），导入时也不改本机的 `initializedAt`。
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.app,
    required this.taskLists,
    required this.tags,
    required this.tasks,
    required this.taskTags,
    required this.subtasks,
    required this.reminders,
    required this.recurrenceRules,
    required this.focusSessions,
    required this.settings,
    this.exportVersion = kExportVersion,
  });

  final int exportVersion;
  final int exportedAt;
  final BackupAppInfo app;

  final List<BackupListRow> taskLists;
  final List<BackupTagRow> tags;
  final List<BackupTaskRow> tasks;
  final List<BackupTaskTagRow> taskTags;
  final List<BackupSubtaskRow> subtasks;
  final List<BackupReminderRow> reminders;
  final List<BackupRecurrenceRow> recurrenceRules;
  final List<BackupFocusSessionRow> focusSessions;
  final AppPreferences settings;
}

/// 一行清单（`task_lists`）。
class BackupListRow {
  const BackupListRow({
    required this.id,
    required this.name,
    required this.color,
    required this.isBuiltIn,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// ARGB。`null` = 不用颜色区分。
  final int? color;

  /// 内置清单（收件箱）不可删除。
  final bool isBuiltIn;

  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'name': name,
    'color': color,
    'isBuiltIn': isBuiltIn,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// 一行标签（`tags`）。
class BackupTagRow {
  const BackupTagRow({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int? color;
  final int createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'name': name,
    'color': color,
    'createdAt': createdAt,
  };
}

/// 一行任务（`tasks`）。
class BackupTaskRow {
  const BackupTaskRow({
    required this.id,
    required this.title,
    required this.note,
    required this.dueDate,
    required this.dueDateHasTime,
    required this.priority,
    required this.status,
    required this.listId,
    required this.recurrenceRuleId,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.estimatedPomodoros,
  });

  final String id;
  final String title;
  final String? note;
  final int? dueDate;
  final bool dueDateHasTime;

  /// `TaskPriority` 的下标。
  final int priority;

  /// `TaskStatus` 的下标。
  final int status;

  final String? listId;
  final String? recurrenceRuleId;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;

  /// 预估番茄数。`null` = 没估过，与「估了 0 个」不同。
  final int? estimatedPomodoros;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'note': note,
    'dueDate': dueDate,
    'dueDateHasTime': dueDateHasTime,
    'priority': priority,
    'status': status,
    'listId': listId,
    'recurrenceRuleId': recurrenceRuleId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
    'estimatedPomodoros': estimatedPomodoros,
  };
}

/// 一行「任务 ↔ 标签」关联（`task_tags`）。这张表只有两个外键组成的复合主键。
class BackupTaskTagRow {
  const BackupTaskTagRow({required this.taskId, required this.tagId});

  final String taskId;
  final String tagId;

  Map<String, Object?> toMap() => <String, Object?>{
    'taskId': taskId,
    'tagId': tagId,
  };
}

/// 一行子任务（`subtasks`）。
class BackupSubtaskRow {
  const BackupSubtaskRow({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int sortOrder;
  final int createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'title': title,
    'isDone': isDone,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };
}

/// 一行提醒（`reminders`）。
class BackupReminderRow {
  const BackupReminderRow({
    required this.id,
    required this.taskId,
    required this.remindAt,
    required this.repeatType,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final String taskId;

  /// 首次触发时刻，UTC 毫秒。
  final int remindAt;

  /// `ReminderRepeatType` 的下标。
  final int repeatType;

  final bool enabled;
  final int createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'remindAt': remindAt,
    'repeatType': repeatType,
    'enabled': enabled,
    'createdAt': createdAt,
  };
}

/// 一行重复规则（`recurrence_rules`）。
class BackupRecurrenceRow {
  const BackupRecurrenceRow({
    required this.id,
    required this.frequency,
    required this.interval,
    required this.startsOn,
    required this.byWeekday,
    required this.byMonthDay,
    required this.endDate,
    required this.endCount,
    required this.createdAt,
  });

  final String id;

  /// `RecurrenceFrequency` 的下标。
  final int frequency;

  final int interval;

  /// 序列锚点，存**完整时刻**（定时任务要保持它的 09:30）。
  final int startsOn;

  /// 逗号分隔的星期下标（`"1,3,5"`），与库里写法一致。
  final String? byWeekday;

  /// 逗号分隔的日号（`"1,15"`），与库里写法一致。
  final String? byMonthDay;

  final int? endDate;
  final int? endCount;
  final int createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'frequency': frequency,
    'interval': interval,
    'startsOn': startsOn,
    'byWeekday': byWeekday,
    'byMonthDay': byMonthDay,
    'endDate': endDate,
    'endCount': endCount,
    'createdAt': createdAt,
  };
}

/// 一行专注记录（`focus_sessions`）。
///
/// 这张表**没有 `createdAt`/`updatedAt`**：一段会话的身份由 `startedAt` 与它
/// 的内容决定，没有「后来改过」这回事（除了补一句备注）。
class BackupFocusSessionRow {
  const BackupFocusSessionRow({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.pausedMillis,
    required this.pausedAt,
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.kind,
    required this.timerMode,
    required this.logicalDate,
    required this.completed,
    required this.note,
  });

  final String id;
  final String? taskId;
  final int startedAt;

  /// `null` = 导出时这段会话还在跑。
  final int? endedAt;

  final int pausedMillis;
  final int? pausedAt;
  final int? plannedSeconds;
  final int actualSeconds;

  /// `FocusSessionKind` 的下标。
  final int kind;

  /// `FocusTimerMode` 的下标。
  final int timerMode;

  /// 归属逻辑日（本地零点毫秒）。
  final int logicalDate;

  final bool completed;
  final String? note;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'pausedMillis': pausedMillis,
    'pausedAt': pausedAt,
    'plannedSeconds': plannedSeconds,
    'actualSeconds': actualSeconds,
    'kind': kind,
    'timerMode': timerMode,
    'logicalDate': logicalDate,
    'completed': completed,
    'note': note,
  };
}
