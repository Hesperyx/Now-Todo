/// 备份文件的读写与校验。
///
/// 只有两个动作：`encodeBackup` 把一份 [BackupData] 变成文本，
/// `decodeBackup` 把文本变成一份**已经检查过**的 [BackupData]。检查放在这里
/// 而不是仓储里，因为它完全是纯逻辑：没有数据库也能测，报错位置（
/// `data.tasks[3].listId`）也不必先有一条 SQL 失败才能算出来。
///
/// 校验的尺度是「宁可整体拒绝，也不要半成功」——半成功是这类功能最难查的
/// 一类故障：用户看到「导入成功」，然后发现少了三分之一的标签。
///
/// 长度约束（标题最长 500 字之类）**不在这里查**：那是数据库的约束，
/// 真撞上了事务会整体回滚，库不会留下半截数据。这里只管结构与引用。
library;

import 'dart:convert';

import '../models/entities.dart';
import '../models/enums.dart';
import 'backup_model.dart';

/// 读文件时遇到的第一个问题。
///
/// 消息是**给用户看的**：说清哪个文件的哪一块不对。技术细节（行列号、
/// 类型名）能省就省，用户改不了那些东西。
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 这个版本的应用还能读多老的文件。
///
/// 低于它的文件连升级链都进不去（升级规则只覆盖「上一版 → 这一版」这段）。
/// 现在只有 v1，所以它和 [kExportVersion] 相等。
const int kOldestExportVersion = 1;

/// 把一份备份写成文本。缩进两个空格：这份文件的另一个用途就是给人看、
/// 给第三方工具解析，挤成一行的 JSON 不满足这个用途。
String encodeBackup(BackupData data) =>
    const JsonEncoder.withIndent('  ').convert(encodeBackupToMap(data));

/// 备份的 JSON 形状（写文件时再交给 [JsonEncoder]）。
///
/// 单独暴露出来是为了测试能直接比对结构，不必反过来去解析文本。
Map<String, Object?> encodeBackupToMap(BackupData data) => <String, Object?>{
  'exportVersion': data.exportVersion,
  'exportedAt': data.exportedAt,
  'app': data.app.toMap(),
  'data': <String, Object?>{
    'taskLists': <Object?>[
      for (final BackupListRow row in data.taskLists) row.toMap(),
    ],
    'tags': <Object?>[for (final BackupTagRow row in data.tags) row.toMap()],
    'tasks': <Object?>[for (final BackupTaskRow row in data.tasks) row.toMap()],
    'taskTags': <Object?>[
      for (final BackupTaskTagRow row in data.taskTags) row.toMap(),
    ],
    'subtasks': <Object?>[
      for (final BackupSubtaskRow row in data.subtasks) row.toMap(),
    ],
    'reminders': <Object?>[
      for (final BackupReminderRow row in data.reminders) row.toMap(),
    ],
    'recurrenceRules': <Object?>[
      for (final BackupRecurrenceRow row in data.recurrenceRules) row.toMap(),
    ],
    'focusSessions': <Object?>[
      for (final BackupFocusSessionRow row in data.focusSessions) row.toMap(),
    ],
    'settings': settingsToMap(data.settings),
  },
};

/// 十二项用户设置。
///
/// `initializedAt` 不写：那是「这台设备第一次打开应用是什么时候」，
/// 换台设备之后它只描述旧设备，搬过去没有任何意义。
Map<String, Object?> settingsToMap(AppPreferences preferences) =>
    <String, Object?>{
      'themeMode': preferences.themeMode.index,
      'defaultView': preferences.defaultView.index,
      'notificationsEnabled': preferences.notificationsEnabled,
      'strongReminders': preferences.strongReminders,
      'focusMinutes': preferences.focusMinutes,
      'shortBreakMinutes': preferences.shortBreakMinutes,
      'longBreakMinutes': preferences.longBreakMinutes,
      'roundsBeforeLongBreak': preferences.roundsBeforeLongBreak,
      'autoStartNext': preferences.autoStartNext,
      'defaultTimerMode': preferences.defaultTimerMode.index,
      'midnightMode': preferences.midnightMode,
      'midnightEndHour': preferences.midnightEndHour,
    };

/// 读一份备份。
///
/// 抛 [BackupFormatException] 时，调用方拿到的错误消息可以直接弹给用户，
/// 且**不会**对数据库造成任何影响——这个函数不碰数据库。
BackupData decodeBackup(String text) {
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException catch (error) {
    throw BackupFormatException('这个文件不是合法的 JSON（${error.message}）。');
  }

  final Map<String, Object?>? root = _asObject(raw);
  if (root == null) {
    throw const BackupFormatException('这个文件的顶层应该是一个对象。');
  }

  final int version = _readVersion(root);
  if (version > kExportVersion) {
    throw BackupFormatException(
      '这个文件来自更新的版本（exportVersion $version，本应用读到 '
      '$kExportVersion）。先升级应用再导入。',
    );
  }
  if (version < kOldestExportVersion) {
    throw BackupFormatException(
      '这个文件太旧了（exportVersion $version），这个版本的应用已经读不了。',
    );
  }

  final Map<String, Object?> document = _upgrade(root, version);
  final BackupData data = _readDocument(document);
  validateBackup(data);
  return data;
}

/// 再检查一遍一份已经构造好的 [BackupData]。
///
/// [decodeBackup] 结束时已经查过一遍；仓储在写库前会再调一次——因为
/// `BackupData` 是可以手搓出来的（测试里就这么干），而「写到一半才发现
/// 有一条任务指向不存在的清单」的代价是整个事务回滚。
void validateBackup(BackupData data) {
  final Set<String> listIds = _uniqueIds(
    data.taskLists.map((BackupListRow row) => row.id),
    'data.taskLists',
  );
  final Set<String> tagIds = _uniqueIds(
    data.tags.map((BackupTagRow row) => row.id),
    'data.tags',
  );
  final Set<String> taskIds = _uniqueIds(
    data.tasks.map((BackupTaskRow row) => row.id),
    'data.tasks',
  );
  _uniqueIds(
    data.subtasks.map((BackupSubtaskRow row) => row.id),
    'data.subtasks',
  );
  _uniqueIds(
    data.reminders.map((BackupReminderRow row) => row.id),
    'data.reminders',
  );
  final Set<String> ruleIds = _uniqueIds(
    data.recurrenceRules.map((BackupRecurrenceRow row) => row.id),
    'data.recurrenceRules',
  );
  _uniqueIds(
    data.focusSessions.map((BackupFocusSessionRow row) => row.id),
    'data.focusSessions',
  );

  for (int i = 0; i < data.tasks.length; i++) {
    final BackupTaskRow row = data.tasks[i];
    final String where = 'data.tasks[$i]';
    _mustPointTo(row.listId, listIds, '$where.listId', '清单');
    _mustPointTo(
      row.recurrenceRuleId,
      ruleIds,
      '$where.recurrenceRuleId',
      '重复规则',
    );
  }

  for (int i = 0; i < data.subtasks.length; i++) {
    final BackupSubtaskRow row = data.subtasks[i];
    _mustPointTo(row.taskId, taskIds, 'data.subtasks[$i].taskId', '任务');
  }

  for (int i = 0; i < data.reminders.length; i++) {
    final BackupReminderRow row = data.reminders[i];
    _mustPointTo(row.taskId, taskIds, 'data.reminders[$i].taskId', '任务');
  }

  for (int i = 0; i < data.focusSessions.length; i++) {
    final BackupFocusSessionRow row = data.focusSessions[i];
    _mustPointTo(row.taskId, taskIds, 'data.focusSessions[$i].taskId', '任务');
  }

  final Set<String> pairs = <String>{};
  for (int i = 0; i < data.taskTags.length; i++) {
    final BackupTaskTagRow row = data.taskTags[i];
    final String where = 'data.taskTags[$i]';
    _mustPointTo(row.taskId, taskIds, '$where.taskId', '任务');
    _mustPointTo(row.tagId, tagIds, '$where.tagId', '标签');
    // 复合主键：同一对出现两次，写库时会撞主键。
    if (!pairs.add('${row.taskId}\u0000${row.tagId}')) {
      throw BackupFormatException('$where 和前面某一条重复：同一个任务贴了两次同一个标签。');
    }
  }
}

// ─────────────────────────── 读文件 ───────────────────────────

BackupData _readDocument(Map<String, Object?> document) {
  final int exportedAt;
  if (!document.containsKey('exportedAt')) {
    throw const BackupFormatException('文件根缺少 exportVersion 旁边的 exportedAt。');
  }
  final Object? stamp = document['exportedAt'];
  if (stamp is! int) {
    throw const BackupFormatException('exportedAt 应该是整数（毫秒时间戳）。');
  }
  exportedAt = stamp;

  final Object? dataNode = document['data'];
  final Map<String, Object?>? data = _asObject(dataNode);
  if (data == null) {
    throw const BackupFormatException('这个文件里没有 data 段。');
  }

  return BackupData(
    exportVersion: kExportVersion,
    exportedAt: exportedAt,
    app: _readApp(document),
    taskLists: _table(data, 'taskLists', _readList),
    tags: _table(data, 'tags', _readTag),
    tasks: _table(data, 'tasks', _readTask),
    taskTags: _table(data, 'taskTags', _readTaskTag),
    subtasks: _table(data, 'subtasks', _readSubtask),
    reminders: _table(data, 'reminders', _readReminder),
    recurrenceRules: _table(data, 'recurrenceRules', _readRule),
    focusSessions: _table(data, 'focusSessions', _readSession),
    settings: _readSettings(data),
  );
}

/// `app` 是给人看的信息块：缺了不影响导入，真正决定能不能读的是
/// `exportVersion`。所以这里「有就读，没有就空」，不与数据段一样的严格。
BackupAppInfo _readApp(Map<String, Object?> document) {
  final Map<String, Object?>? app = _asObject(document['app']);
  if (app == null) {
    return const BackupAppInfo(name: '', version: '', schemaVersion: 0);
  }
  final Object? name = app['name'];
  final Object? version = app['version'];
  final Object? schema = app['schemaVersion'];
  return BackupAppInfo(
    name: name is String ? name : '',
    version: version is String ? version : '',
    schemaVersion: schema is int ? schema : 0,
  );
}

int _readVersion(Map<String, Object?> root) {
  if (!root.containsKey('exportVersion')) {
    throw const BackupFormatException('这不是一份 Now Todo 备份：文件里没有 exportVersion。');
  }
  final Object? value = root['exportVersion'];
  if (value is! int) {
    throw const BackupFormatException('exportVersion 应该是整数。');
  }
  return value;
}

/// 把旧文件升到当前版本。
///
/// 现在只有 v1，所以循环体是空的——但结构留着。等真加 v2 时，这里补一条
/// `case 1: root = _upgradeV1ToV2(root);`，老文件就自动能读了。
/// 没有这个循环，下次改格式的人只能在「直接拒绝老文件」和「在读取处到处写
/// `if (version < 2)`」之间选，两条路都会在半年后变成事故。
Map<String, Object?> _upgrade(Map<String, Object?> root, int from) {
  for (int version = from; version < kExportVersion; version++) {
    // 每一轮负责把 root 从 version 升到 version + 1：
    // 加 v2 时在这里补 `case 1: root = _upgradeV1ToV2(root);`。
  }
  return root;
}

List<T> _table<T>(
  Map<String, Object?> data,
  String name,
  T Function(_Row row) read,
) {
  if (!data.containsKey(name)) {
    throw BackupFormatException('data 段缺少 $name。');
  }
  final Object? node = data[name];
  if (node is! List) {
    throw BackupFormatException('data.$name 应该是数组。');
  }
  final List<T> rows = <T>[];
  for (int i = 0; i < node.length; i++) {
    final Map<String, Object?>? item = _asObject(node[i]);
    if (item == null) {
      throw BackupFormatException('data.$name[$i] 应该是一个对象。');
    }
    rows.add(read(_Row('data.$name[$i]', item)));
  }
  return rows;
}

BackupListRow _readList(_Row row) => BackupListRow(
  id: row.str('id'),
  name: row.str('name'),
  color: row.intOrNull('color'),
  isBuiltIn: row.boolean('isBuiltIn'),
  sortOrder: row.intOf('sortOrder'),
  createdAt: row.intOf('createdAt'),
  updatedAt: row.intOf('updatedAt'),
);

BackupTagRow _readTag(_Row row) => BackupTagRow(
  id: row.str('id'),
  name: row.str('name'),
  color: row.intOrNull('color'),
  createdAt: row.intOf('createdAt'),
);

BackupTaskRow _readTask(_Row row) => BackupTaskRow(
  id: row.str('id'),
  title: row.str('title'),
  note: row.stringOrNull('note'),
  dueDate: row.intOrNull('dueDate'),
  dueDateHasTime: row.boolean('dueDateHasTime'),
  priority: row.option('priority', TaskPriority.values.length),
  status: row.option('status', TaskStatus.values.length),
  listId: row.stringOrNull('listId'),
  recurrenceRuleId: row.stringOrNull('recurrenceRuleId'),
  createdAt: row.intOf('createdAt'),
  updatedAt: row.intOf('updatedAt'),
  completedAt: row.intOrNull('completedAt'),
  estimatedPomodoros: row.intOrNull('estimatedPomodoros'),
);

BackupTaskTagRow _readTaskTag(_Row row) =>
    BackupTaskTagRow(taskId: row.str('taskId'), tagId: row.str('tagId'));

BackupSubtaskRow _readSubtask(_Row row) => BackupSubtaskRow(
  id: row.str('id'),
  taskId: row.str('taskId'),
  title: row.str('title'),
  isDone: row.boolean('isDone'),
  sortOrder: row.intOf('sortOrder'),
  createdAt: row.intOf('createdAt'),
);

BackupReminderRow _readReminder(_Row row) => BackupReminderRow(
  id: row.str('id'),
  taskId: row.str('taskId'),
  remindAt: row.intOf('remindAt'),
  repeatType: row.option('repeatType', ReminderRepeatType.values.length),
  enabled: row.boolean('enabled'),
  createdAt: row.intOf('createdAt'),
);

BackupRecurrenceRow _readRule(_Row row) => BackupRecurrenceRow(
  id: row.str('id'),
  frequency: row.option('frequency', RecurrenceFrequency.values.length),
  interval: row.intOf('interval'),
  startsOn: row.intOf('startsOn'),
  byWeekday: row.csvOrNull('byWeekday'),
  byMonthDay: row.csvOrNull('byMonthDay'),
  endDate: row.intOrNull('endDate'),
  endCount: row.intOrNull('endCount'),
  createdAt: row.intOf('createdAt'),
);

BackupFocusSessionRow _readSession(_Row row) => BackupFocusSessionRow(
  id: row.str('id'),
  taskId: row.stringOrNull('taskId'),
  startedAt: row.intOf('startedAt'),
  endedAt: row.intOrNull('endedAt'),
  pausedMillis: row.intOf('pausedMillis'),
  pausedAt: row.intOrNull('pausedAt'),
  plannedSeconds: row.intOrNull('plannedSeconds'),
  actualSeconds: row.intOf('actualSeconds'),
  kind: row.option('kind', FocusSessionKind.values.length),
  timerMode: row.option('timerMode', FocusTimerMode.values.length),
  logicalDate: row.intOf('logicalDate'),
  completed: row.boolean('completed'),
  note: row.stringOrNull('note'),
);

AppPreferences _readSettings(Map<String, Object?> data) {
  if (!data.containsKey('settings')) {
    throw const BackupFormatException('data 段缺少 settings。');
  }
  final Map<String, Object?>? node = _asObject(data['settings']);
  if (node == null) {
    throw const BackupFormatException('data.settings 应该是一个对象。');
  }
  final _Row row = _Row('data.settings', node);
  return AppPreferences(
    themeMode: ThemeModeSetting
        .values[row.option('themeMode', ThemeModeSetting.values.length)],
    defaultView: DefaultView
        .values[row.option('defaultView', DefaultView.values.length)],
    notificationsEnabled: row.boolean('notificationsEnabled'),
    strongReminders: row.boolean('strongReminders'),
    focusMinutes: row.intOf('focusMinutes'),
    shortBreakMinutes: row.intOf('shortBreakMinutes'),
    longBreakMinutes: row.intOf('longBreakMinutes'),
    roundsBeforeLongBreak: row.intOf('roundsBeforeLongBreak'),
    autoStartNext: row.boolean('autoStartNext'),
    defaultTimerMode: FocusTimerMode
        .values[row.option('defaultTimerMode', FocusTimerMode.values.length)],
    midnightMode: row.boolean('midnightMode'),
    midnightEndHour: row.intOf('midnightEndHour'),
  );
}

// ─────────────────────────── 取值与检查 ───────────────────────────

/// 读一行时用的取值器。
///
/// 每个取值失败都会带上「哪一行哪一列」，因为用户唯一能拿到的线索就是这句话；
/// 「类型转换失败」这种消息等于没说。
///
/// 可空列在文件里**写出 `null`**，而不是省略键——「键不存在」在这里一律当成
/// 文件坏了：省略键通常是手改文件或者别处生成的半成品，猜它的意思不如说清楚。
class _Row {
  const _Row(this.path, this.map);

  final String path;
  final Map<String, Object?> map;

  Object? _raw(String key) {
    if (!map.containsKey(key)) {
      throw BackupFormatException('$path 缺少 $key。');
    }
    return map[key];
  }

  String str(String key) {
    final Object? value = _raw(key);
    if (value is! String) {
      throw BackupFormatException('$path.$key 应该是字符串。');
    }
    return value;
  }

  String? stringOrNull(String key) {
    final Object? value = _raw(key);
    if (value == null) return null;
    if (value is! String) {
      throw BackupFormatException('$path.$key 应该是字符串或 null。');
    }
    return value;
  }

  int intOf(String key) {
    final Object? value = _raw(key);
    if (value is! int) {
      throw BackupFormatException('$path.$key 应该是整数。');
    }
    return value;
  }

  int? intOrNull(String key) {
    final Object? value = _raw(key);
    if (value == null) return null;
    if (value is! int) {
      throw BackupFormatException('$path.$key 应该是整数或 null。');
    }
    return value;
  }

  bool boolean(String key) {
    final Object? value = _raw(key);
    if (value is! bool) {
      throw BackupFormatException('$path.$key 应该是 true 或 false。');
    }
    return value;
  }

  /// 枚举在文件里存下标。越界的下标要在读的时候拦下来：写进库之后
  /// `intEnum` 再读出来会直接抛，那时用户看到的是崩溃而不是一句话。
  int option(String key, int count) {
    final int value = intOf(key);
    if (value < 0 || value >= count) {
      throw BackupFormatException(
        '$path.$key 的值是 $value，不在 0 到 ${count - 1} 之间。',
      );
    }
    return value;
  }

  /// 逗号分隔的数字文本（`byWeekday` / `byMonthDay`）。
  ///
  /// 文件里保持与库里一样的写法，而不是拆成数组：这样导出、导入、直接看库
  /// 三处的样子一致，少一层要解释的翻译。
  String? csvOrNull(String key) {
    final String? raw = stringOrNull(key);
    if (raw == null || raw.isEmpty) return null;
    for (final String part in raw.split(',')) {
      if (int.tryParse(part.trim()) == null) {
        throw BackupFormatException('$path.$key 里的「$part」不是数字。');
      }
    }
    return raw;
  }
}

Set<String> _uniqueIds(Iterable<String> ids, String where) {
  final Set<String> seen = <String>{};
  int index = 0;
  for (final String id in ids) {
    if (id.isEmpty) {
      throw BackupFormatException('$where[$index].id 是空的。');
    }
    if (!seen.add(id)) {
      throw BackupFormatException('$where[$index].id「$id」和前面某一条重复。');
    }
    index++;
  }
  return seen;
}

void _mustPointTo(String? id, Set<String> known, String where, String what) {
  if (id != null && !known.contains(id)) {
    throw BackupFormatException('$where 指向的$what（$id）不在这个文件里。');
  }
}

Map<String, Object?>? _asObject(Object? node) {
  if (node is! Map) return null;
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in node.entries) {
    final Object? key = entry.key;
    if (key is! String) return null;
    result[key] = entry.value;
  }
  return result;
}
