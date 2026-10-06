import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/backup/backup_codec.dart';
import 'package:now_todo/core/backup/backup_model.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';

void main() {
  /// 一份「什么都有」的备份：两个清单、一个标签、一条挂了规则/子任务/提醒的
  /// 任务、一段专注记录，设置也改过。八张表 + 设置全在场，往返才对得上。
  BackupData sample() => BackupData(
    exportedAt: 1760000000000,
    app: const BackupAppInfo(
      name: 'now_todo',
      version: '1.0.0+1',
      schemaVersion: 4,
    ),
    taskLists: const <BackupListRow>[
      BackupListRow(
        id: 'builtin-inbox',
        name: '收件箱',
        color: null,
        isBuiltIn: true,
        sortOrder: 0,
        createdAt: 1000,
        updatedAt: 1000,
      ),
      BackupListRow(
        id: 'list-work',
        name: '工作',
        color: 0xFF00FF00,
        isBuiltIn: false,
        sortOrder: 1,
        createdAt: 2000,
        updatedAt: 3000,
      ),
    ],
    tags: const <BackupTagRow>[
      BackupTagRow(id: 'tag-1', name: '要事', color: 0xFFFF0000, createdAt: 1500),
    ],
    recurrenceRules: const <BackupRecurrenceRow>[
      BackupRecurrenceRow(
        id: 'rule-1',
        frequency: 1,
        interval: 2,
        startsOn: 2500,
        byWeekday: '1,3,5',
        byMonthDay: null,
        endDate: null,
        endCount: 10,
        createdAt: 2500,
      ),
    ],
    tasks: <BackupTaskRow>[
      BackupTaskRow(
        id: 'task-1',
        title: '交周报',
        note: '写清楚这周做了什么',
        dueDate: 5000,
        dueDateHasTime: true,
        priority: TaskPriority.high.index,
        status: TaskStatus.pending.index,
        listId: 'list-work',
        recurrenceRuleId: 'rule-1',
        createdAt: 2600,
        updatedAt: 2700,
        completedAt: null,
        estimatedPomodoros: 2,
      ),
    ],
    taskTags: const <BackupTaskTagRow>[
      BackupTaskTagRow(taskId: 'task-1', tagId: 'tag-1'),
    ],
    subtasks: const <BackupSubtaskRow>[
      BackupSubtaskRow(
        id: 'sub-1',
        taskId: 'task-1',
        title: '先收集数据',
        isDone: false,
        sortOrder: 0,
        createdAt: 2800,
      ),
    ],
    reminders: const <BackupReminderRow>[
      BackupReminderRow(
        id: 'rem-1',
        taskId: 'task-1',
        remindAt: 6000,
        repeatType: 1,
        enabled: true,
        createdAt: 2900,
      ),
    ],
    focusSessions: const <BackupFocusSessionRow>[
      BackupFocusSessionRow(
        id: 'fs-1',
        taskId: 'task-1',
        startedAt: 7000,
        endedAt: 8500,
        pausedMillis: 0,
        pausedAt: null,
        plannedSeconds: 1500,
        actualSeconds: 1500,
        kind: 0,
        timerMode: 1,
        logicalDate: 6900,
        completed: true,
        note: null,
      ),
    ],
    settings: const AppPreferences(
      themeMode: ThemeModeSetting.dark,
      focusMinutes: 30,
      midnightMode: true,
    ),
  );

  /// 把一份备份编成 JSON，再按需改一处，模拟「文件被人改坏了」。
  String json(void Function(Map<String, Object?> root) mutate) {
    final Map<String, Object?> root = encodeBackupToMap(sample());
    mutate(root);
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  Object? at(Map<String, Object?> root, String path) {
    Object? node = root;
    for (final String key in path.split('.')) {
      final int? index = int.tryParse(key);
      node = index == null
          ? (node! as Map<String, Object?>)[key]
          : (node! as List<Object?>)[index];
    }
    return node;
  }

  void write(Map<String, Object?> root, String path, Object? value) {
    final List<String> keys = path.split('.');
    Object? node = root;
    for (final String key in keys.take(keys.length - 1)) {
      final int? index = int.tryParse(key);
      node = index == null
          ? (node! as Map<String, Object?>)[key]
          : (node! as List<Object?>)[index];
    }
    final String last = keys.last;
    final int? index = int.tryParse(last);
    if (index == null) {
      (node! as Map<String, Object?>)[last] = value;
    } else {
      (node! as List<Object?>)[index] = value;
    }
  }

  group('往返 · 编出来的能读回去', () {
    test('八张表与设置原样来回', () {
      final BackupData back = decodeBackup(encodeBackup(sample()));
      expect(encodeBackupToMap(back), encodeBackupToMap(sample()));
    });

    test('空库也能编出合法 JSON', () {
      final BackupData empty = BackupData(
        exportedAt: 1760000000000,
        app: const BackupAppInfo(
          name: 'now_todo',
          version: '',
          schemaVersion: 4,
        ),
        taskLists: const <BackupListRow>[],
        tags: const <BackupTagRow>[],
        tasks: const <BackupTaskRow>[],
        taskTags: const <BackupTaskTagRow>[],
        subtasks: const <BackupSubtaskRow>[],
        reminders: const <BackupReminderRow>[],
        recurrenceRules: const <BackupRecurrenceRow>[],
        focusSessions: const <BackupFocusSessionRow>[],
        settings: const AppPreferences(),
      );
      final String text = encodeBackup(empty);
      expect(jsonDecode(text), isA<Map<String, Object?>>());
      expect(decodeBackup(text).tasks, isEmpty);
    });

    test('缩进过的人话，第三方工具能直接看', () {
      final String text = encodeBackup(sample());
      expect(text, contains('\n  "exportVersion": 1,'));
      expect(text, contains('\n  "data": {'));
      expect(text, contains('\n        "title": "交周报",'));
    });

    test('枚举存下标，逗号文本与库里一致', () {
      final Map<String, Object?> data =
          encodeBackupToMap(sample())['data']! as Map<String, Object?>;
      final Map<String, Object?> task =
          (data['tasks']! as List<Object?>).first! as Map<String, Object?>;
      final Map<String, Object?> rule =
          (data['recurrenceRules']! as List<Object?>).first!
              as Map<String, Object?>;
      expect(task['priority'], TaskPriority.high.index);
      expect(task['status'], TaskStatus.pending.index);
      expect(rule['byWeekday'], '1,3,5');
      expect(rule['byMonthDay'], isNull);
    });

    test('设置里不写 initializedAt（那是设备的记账）', () {
      final Map<String, Object?> data =
          encodeBackupToMap(sample())['data']! as Map<String, Object?>;
      final Map<String, Object?> settings =
          data['settings']! as Map<String, Object?>;
      expect(settings.containsKey('initializedAt'), isFalse);
      expect(settings['focusMinutes'], 30);
      expect(settings['midnightEndHour'], 4);
    });
  });

  group('根与版本 · 先看清这是什么文件', () {
    test('不是 JSON', () {
      expect(
        () => decodeBackup('这不是 json'),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('不是合法的 JSON'),
          ),
        ),
      );
    });

    test('顶层是数组', () {
      expect(
        () => decodeBackup('[1, 2, 3]'),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('顶层应该是一个对象'),
          ),
        ),
      );
    });

    test('没有 exportVersion', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root.remove('exportVersion')),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('没有 exportVersion'),
          ),
        ),
      );
    });

    test('exportVersion 不是整数', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root['exportVersion'] = '1'),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('应该是整数'),
          ),
        ),
      );
    });

    test('来自更新的版本：让他去升级，别猜', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root['exportVersion'] = 99),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            allOf(contains('更新的版本'), contains('升级')),
          ),
        ),
      );
    });

    test('版本号低到没有读法', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root['exportVersion'] = 0),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('太旧'),
          ),
        ),
      );
    });

    test('没有 exportedAt', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root.remove('exportedAt')),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('exportedAt'),
          ),
        ),
      );
    });
  });

  group('字段 · 坏在哪一行要说清楚', () {
    test('没有 data 段', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => root.remove('data')),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('没有 data 段'),
          ),
        ),
      );
    });

    test('缺一张表', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                (root['data']! as Map<String, Object?>).remove('subtasks'),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data 段缺少 subtasks'),
          ),
        ),
      );
    });

    test('表不是数组', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks', <String, Object?>{}),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.tasks 应该是数组'),
          ),
        ),
      );
    });

    test('元素不是对象', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) => write(root, 'data.tags.0', 7)),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.tags[0] 应该是一个对象'),
          ),
        ),
      );
    });

    test('字段类型不对：报出行号与列名', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks.0.title', 42),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.tasks[0].title 应该是字符串'),
          ),
        ),
      );
    });

    test('可空列写 null 可以，省略键不行', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks.0.note', null),
          ),
        ),
        returnsNormally,
      );
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                (at(root, 'data.tasks.0')! as Map<String, Object?>).remove(
                  'note',
                ),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.tasks[0] 缺少 note'),
          ),
        ),
      );
    });

    test('枚举下标越界', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks.0.priority', 9),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('不在 0 到 3 之间'),
          ),
        ),
      );
    });

    test('逗号文本里混了不是数字的东西', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.recurrenceRules.0.byWeekday', '1,二,3'),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            allOf(contains('byWeekday'), contains('二'), contains('不是数字')),
          ),
        ),
      );
    });

    test('设置段缺字段', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                (at(root, 'data.settings')! as Map<String, Object?>).remove(
                  'focusMinutes',
                ),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.settings 缺少 focusMinutes'),
          ),
        ),
      );
    });

    test('多出来的陌生字段被忽略：别人的工具加过东西也读得进来', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) {
            root['extra'] = <String, Object?>{'note': '第三方写的'};
            write(root, 'data.tasks.0.colorTag', '蓝');
          }),
        ),
        returnsNormally,
      );
    });

    test('app 段是给人看的：缺了也能读', () {
      final BackupData data = decodeBackup(
        json((Map<String, Object?> root) => root.remove('app')),
      );
      expect(data.app.name, '');
      expect(data.app.schemaVersion, 0);
      expect(data.tasks, hasLength(1));
    });
  });

  group('结构 · 写库之前先把错误挡住', () {
    test('同一张表里 id 重复', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) {
            final List<Object?> tags = at(root, 'data.tags')! as List<Object?>;
            tags.add(
              Map<String, Object?>.from(tags.first! as Map<String, Object?>),
            );
          }),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('重复'),
          ),
        ),
      );
    });

    test('id 是空的', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) => write(root, 'data.tags.0.id', ''),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('data.tags[0].id 是空的'),
          ),
        ),
      );
    });

    test('任务指向不存在的清单', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks.0.listId', 'list-ghost'),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            allOf(contains('list-ghost'), contains('清单')),
          ),
        ),
      );
    });

    test('任务指向不存在的重复规则', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.tasks.0.recurrenceRuleId', 'rule-ghost'),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('重复规则'),
          ),
        ),
      );
    });

    test('子任务/提醒/专注记录指向不存在的任务', () {
      for (final String path in <String>[
        'data.subtasks.0.taskId',
        'data.reminders.0.taskId',
        'data.focusSessions.0.taskId',
      ]) {
        expect(
          () => decodeBackup(
            json(
              (Map<String, Object?> root) => write(root, path, 'task-ghost'),
            ),
          ),
          throwsA(isA<BackupFormatException>()),
          reason: '$path 悬空时应该被拦下',
        );
      }
    });

    test('标签关系两头都要在文件里', () {
      expect(
        () => decodeBackup(
          json(
            (Map<String, Object?> root) =>
                write(root, 'data.taskTags.0.tagId', 'tag-ghost'),
          ),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('标签'),
          ),
        ),
      );
    });

    test('同一个任务贴了两次同一个标签', () {
      expect(
        () => decodeBackup(
          json((Map<String, Object?> root) {
            final List<Object?> pairs =
                at(root, 'data.taskTags')! as List<Object?>;
            pairs.add(
              Map<String, Object?>.from(pairs.first! as Map<String, Object?>),
            );
          }),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (BackupFormatException e) => e.message,
            'message',
            contains('贴了两次'),
          ),
        ),
      );
    });

    test('validateBackup 手搓的数据也拦得住', () {
      final BackupData data = BackupData(
        exportedAt: 1,
        app: const BackupAppInfo(
          name: 'now_todo',
          version: '',
          schemaVersion: 4,
        ),
        taskLists: const <BackupListRow>[],
        tags: const <BackupTagRow>[],
        tasks: const <BackupTaskRow>[],
        taskTags: const <BackupTaskTagRow>[
          BackupTaskTagRow(taskId: 'task-1', tagId: 'tag-1'),
        ],
        subtasks: const <BackupSubtaskRow>[],
        reminders: const <BackupReminderRow>[],
        recurrenceRules: const <BackupRecurrenceRow>[],
        focusSessions: const <BackupFocusSessionRow>[],
        settings: const AppPreferences(),
      );
      expect(() => validateBackup(data), throwsA(isA<BackupFormatException>()));
    });
  });
}
