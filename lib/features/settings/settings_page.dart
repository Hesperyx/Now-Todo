import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/backup/backup_codec.dart';
import '../../core/backup/backup_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/focus/focus_settings.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/backup/backup_file_service.dart';
import '../../data/repositories/backup_repository.dart';

/// 设置页写回偏好的那一次调用。抽成别名只是为了让子组件的构造参数短一点，
/// 真正的实现仍然只有一个（`SettingsPage.build` 里的 `write` 闭包）。
typedef _PreferencesWrite =
    Future<void> Function({
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
    });

/// 设置页。
///
/// 原则：只放「真的会生效」的开关。做不到的事不写进来，写了做不到的开关
/// 比没有这个开关更糟——用户会以为自己已经打开了某个保护。
///
/// 通知区块里混了两种东西，措辞上刻意分开：**设置项**是应用能改的，
/// **系统权限状态**是应用改不了的，只能如实显示并给一个入口。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences preferences =
        ref.watch(preferencesProvider).valueOrNull ?? const AppPreferences();

    Future<void> write({
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
    }) async {
      try {
        await ref
            .read(settingsRepositoryProvider)
            .update(
              themeMode: themeMode,
              defaultView: defaultView,
              notificationsEnabled: notificationsEnabled,
              strongReminders: strongReminders,
              focusMinutes: focusMinutes,
              shortBreakMinutes: shortBreakMinutes,
              longBreakMinutes: longBreakMinutes,
              roundsBeforeLongBreak: roundsBeforeLongBreak,
              autoStartNext: autoStartNext,
              defaultTimerMode: defaultTimerMode,
              midnightMode: midnightMode,
              midnightEndHour: midnightEndHour,
            );
      } on Object catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('没能保存设置：$error')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              const _SectionHeader(text: '外观'),
              _SettingBlock(
                title: '主题',
                subtitle: '「跟随系统」会随系统深浅色切换。',
                child: SegmentedButton<ThemeModeSetting>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<ThemeModeSetting>>[
                    for (final ThemeModeSetting mode in ThemeModeSetting.values)
                      ButtonSegment<ThemeModeSetting>(
                        value: mode,
                        label: Text(mode.label),
                      ),
                  ],
                  selected: <ThemeModeSetting>{preferences.themeMode},
                  onSelectionChanged: (Set<ThemeModeSetting> selection) =>
                      write(themeMode: selection.first),
                ),
              ),
              const Divider(height: 32),
              const _SectionHeader(text: '启动'),
              _SettingBlock(
                title: '默认视图',
                subtitle: '打开应用时先看哪个视图。切换视图不会改这里。',
                child: SegmentedButton<DefaultView>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<DefaultView>>[
                    for (final DefaultView view in DefaultView.values)
                      ButtonSegment<DefaultView>(
                        value: view,
                        label: Text(view.label),
                      ),
                  ],
                  selected: <DefaultView>{preferences.defaultView},
                  onSelectionChanged: (Set<DefaultView> selection) =>
                      write(defaultView: selection.first),
                ),
              ),
              const Divider(height: 32),
              const _SectionHeader(text: '通知'),
              _NotificationSection(
                preferences: preferences,
                onNotificationsChanged: (bool value) =>
                    write(notificationsEnabled: value),
                onStrongChanged: (bool value) => write(strongReminders: value),
              ),
              const Divider(height: 32),
              const _SectionHeader(text: '专注'),
              _FocusSection(preferences: preferences, write: write),
              const Divider(height: 32),
              const _SectionHeader(text: '数据'),
              const _DataSection(),
              const Divider(height: 32),
              const _SectionHeader(text: '其他'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本、开源许可、捐赠'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.about),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通知设置：两个开关 + 系统权限现状。
///
/// 这里混了三层意思，措辞上刻意分开：
/// - 「提醒」是应用的总开关，关掉会撤销已排的通知，但提醒配置本身保留；
/// - 「强提醒」只影响接下来排的通知；
/// - 下面的权限行是**系统的**状态，应用改不了，只能如实显示并给一个入口。
///
/// 权限被拒时提醒是静默不响的。如果这里不写，用户会一直等一个永远不会
/// 来的通知，然后认定这个功能本来就是坏的——那是我们让他误判的。
class _NotificationSection extends ConsumerWidget {
  const _NotificationSection({
    required this.preferences,
    required this.onNotificationsChanged,
    required this.onStrongChanged,
  });

  final AppPreferences preferences;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onStrongChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<NotificationPermissionStatus> permission = ref.watch(
      notificationPermissionProvider,
    );
    final int scheduled = ref.watch(reminderSchedulerProvider).scheduledCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          value: preferences.notificationsEnabled,
          title: const Text('提醒'),
          subtitle: const Text('关掉之后已经排好的提醒会一并撤销，提醒的配置本身保留。'),
          onChanged: onNotificationsChanged,
        ),
        SwitchListTile(
          value: preferences.strongReminders,
          title: const Text('强提醒'),
          subtitle: const Text(
            '到点后持续响铃，直到你处理掉这条通知。'
            '系统的勿扰与静音仍会压制它——这不是应用能绕开的。',
          ),
          // 总开关关着时强提醒没有意义：置灰而不是藏起来，
          // 藏起来会让用户以为这个功能根本不存在。
          onChanged: preferences.notificationsEnabled ? onStrongChanged : null,
        ),
        permission.when(
          data: (NotificationPermissionStatus status) =>
              _PermissionStatus(status: status),
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '读不到系统的通知权限状态：$error',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        if (preferences.notificationsEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              scheduled == 0 ? '当前没有已排程的提醒。' : '已排程 $scheduled 条提醒。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// 系统权限现状 + 一个入口。
///
/// 只显示状态，不假装能替用户决定：真正的授权动作在系统界面里完成，
/// 这里最多把系统界面调起来，然后把状态重新查一遍。
class _PermissionStatus extends ConsumerWidget {
  const _PermissionStatus({required this.status});

  final NotificationPermissionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool allowed = status.notificationsAllowed;
    final bool exact = status.exactAlarmsAllowed;
    final bool ok = status.isFullyAllowed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _describe(allowed: allowed, exact: exact),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final NotificationService service = ref.read(
                notificationServiceProvider,
              );
              if (!allowed) {
                await service.requestPermission();
              } else if (!exact) {
                await service.requestExactAlarmPermission();
              }
              // 权限可能刚变（比如从不精确变成准点），重查状态并重排提醒。
              ref.invalidate(notificationPermissionProvider);
              await ref.read(reminderSchedulerProvider).refresh();
            },
            child: Text(!allowed ? '申请权限' : (exact ? '重新检查' : '去授权')),
          ),
        ],
      ),
    );
  }

  static String _describe({required bool allowed, required bool exact}) {
    if (!allowed) {
      return '系统还没有允许应用发通知，提醒不会响。'
          '去「系统设置 → 通知」里打开本应用的通知。';
    }
    if (!exact) {
      return '系统没有给精确闹钟权限，提醒仍会响，但可能晚几分钟。'
          '要准点就去「系统设置 → 应用 → 特殊权限」里打开。';
    }
    return '系统已允许通知与精确闹钟，提醒会准点响。';
  }
}

/// 专注计时的参数。
///
/// 时长一律走 [_MinutesField] 而不是开关式预设：番茄钟的时长是很个人的
/// 东西（有人 25 有人 50），给几个固定档位总会有人落在档位之间。
class _FocusSection extends StatelessWidget {
  const _FocusSection({required this.preferences, required this.write});

  final AppPreferences preferences;
  final _PreferencesWrite write;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SettingBlock(
          title: '默认模式',
          subtitle: '打开专注页时先选中的那一个，随时可以在页面上改。',
          child: SegmentedButton<FocusTimerMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<FocusTimerMode>>[
              for (final FocusTimerMode mode in FocusTimerMode.values)
                ButtonSegment<FocusTimerMode>(
                  value: mode,
                  label: Text(mode.label),
                ),
            ],
            selected: <FocusTimerMode>{preferences.defaultTimerMode},
            onSelectionChanged: (Set<FocusTimerMode> selection) =>
                write(defaultTimerMode: selection.first),
          ),
        ),
        _MinutesField(
          title: '专注时长',
          value: preferences.focusMinutes,
          kind: FocusSessionKind.focus,
          onChanged: (int value) => write(focusMinutes: value),
        ),
        _MinutesField(
          title: '短休息',
          value: preferences.shortBreakMinutes,
          kind: FocusSessionKind.shortBreak,
          onChanged: (int value) => write(shortBreakMinutes: value),
        ),
        _MinutesField(
          title: '长休息',
          value: preferences.longBreakMinutes,
          kind: FocusSessionKind.longBreak,
          onChanged: (int value) => write(longBreakMinutes: value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('每几轮一次长休息')),
              DropdownButton<int>(
                value: preferences.roundsBeforeLongBreak,
                items: <DropdownMenuItem<int>>[
                  for (int rounds = 2; rounds <= 8; rounds++)
                    DropdownMenuItem<int>(
                      value: rounds,
                      child: Text('$rounds 轮'),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) write(roundsBeforeLongBreak: value);
                },
              ),
            ],
          ),
        ),
        SwitchListTile(
          value: preferences.autoStartNext,
          title: const Text('自动接续下一段'),
          subtitle: const Text(
            '一段走满之后自动开始下一段，不用手动点。'
            '缺点是你离开工位之后计时器还在跑，统计里会多出一段没人专注的时间。',
          ),
          onChanged: (bool value) => write(autoStartNext: value),
        ),
        SwitchListTile(
          value: preferences.midnightMode,
          title: const Text('午夜模式'),
          subtitle: const Text('把凌晨算作前一天。夜里工作的人不该在 0 点被切成两天。'),
          onChanged: (bool value) => write(midnightMode: value),
        ),
        if (preferences.midnightMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                const Expanded(child: Text('几点算新的一天')),
                DropdownButton<int>(
                  value: preferences.midnightEndHour,
                  items: <DropdownMenuItem<int>>[
                    for (int hour = 0; hour <= 6; hour++)
                      DropdownMenuItem<int>(
                        value: hour,
                        child: Text(hour == 0 ? '0 点（等于关闭）' : '$hour 点'),
                      ),
                  ],
                  onChanged: (int? value) {
                    if (value != null) write(midnightEndHour: value);
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            '午夜模式只影响统计归到哪一天，不影响计时本身。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 导入导出。
///
/// 两件事都只在用户点头之后才动数据：导出是只读的；导入在真正写库之前会先把
/// 文件整体解一遍（解不开就只报错，库里一个字节都不动），再让用户选合并还是覆盖。
/// 按钮上写「覆盖」而不是「替换」，是因为前者更容易让人停下来看一秒。
class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('导出数据'),
          subtitle: const Text('任务、清单、标签、提醒与专注记录写成一个 JSON 文件'),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _busy ? null : _export,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('导入数据'),
          subtitle: const Text('从备份文件恢复，可以选合并或覆盖'),
          onTap: _busy ? null : _import,
        ),
      ],
    );
  }

  Future<void> _export() async {
    final BackupRepository repository = ref.read(backupRepositoryProvider);
    final BackupFileService files = ref.read(backupFileServiceProvider);
    setState(() => _busy = true);
    try {
      final BackupData data = await repository.export(
        appVersion: await _appVersion(),
      );
      await files.share(
        encodeBackup(data),
        fileName: _fileName(data.exportedAt),
        subject: '${AppConstants.appName} 备份',
      );
      if (!mounted) return;
      _report('备份已生成，选一个地方存下来吧。');
    } on Object catch (error) {
      if (!mounted) return;
      _report('导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final String? text;
    try {
      text = await ref.read(backupFileServiceProvider).pickText();
    } on Object catch (error) {
      if (mounted) _report('$error');
      return;
    }
    // 用户在文件选择器里点了取消：什么都不做，也不用提示。
    if (text == null) return;

    final BackupData data;
    try {
      data = decodeBackup(text);
    } on BackupFormatException catch (error) {
      // 文件本身的问题：把原因说清楚，然后到此为止，库里什么都没动。
      _report(error.message);
      return;
    } on Object catch (error) {
      _report('这份备份读不出来：$error');
      return;
    }

    if (!mounted) return;
    final ImportMode? mode = await _askMode(data);
    if (mode == null) return;

    final BackupRepository repository = ref.read(backupRepositoryProvider);
    setState(() => _busy = true);
    try {
      final ImportOutcome outcome = await repository.importData(
        data,
        mode: mode,
      );
      if (!mounted) return;
      _report(outcome.summary);
    } on Object catch (error) {
      // 导入是一个事务，失败时库里还是导入前那个样子——这句承诺要说出来，
      // 否则用户只能自己猜「现在到底脏没脏」。
      if (!mounted) return;
      _report('导入失败，数据没有变：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 问清楚合并还是覆盖，两个按钮都写明白会发生什么。
  Future<ImportMode?> _askMode(BackupData data) {
    return showDialog<ImportMode>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('怎么导入？'),
        content: Text(
          '文件里有 ${data.tasks.length} 条任务、${data.taskLists.length} 个清单、'
          '${data.tags.length} 个标签、${data.focusSessions.length} 段专注记录。\n\n'
          '合并：只补本地没有的；同一段记录本地那份更新就保留本地的。\n'
          '覆盖：先清掉现在的全部数据，再整份写进去。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.merge),
            child: const Text('合并导入'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.overwrite),
            child: const Text('覆盖导入'),
          ),
        ],
      ),
    );
  }

  String _fileName(int exportedAt) =>
      '${AppConstants.exportFilePrefix}-${formatDate(exportedAt)}.json';

  /// 应用的版本号只写进文件头部给人看，取不到也不该让整个导出失败
  /// （`appVersionProvider` 查不到时给的是空串）。
  Future<String> _appVersion() => ref.read(appVersionProvider.future);

  void _report(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 一个带校验的分钟数输入框。
///
/// 越界时不写回库、只在框下面显示原因：把用户打了一半的数字直接改掉，
/// 他会以为自己打错了，而其实是我们在背后动了手。
class _MinutesField extends StatefulWidget {
  const _MinutesField({
    required this.title,
    required this.value,
    required this.kind,
    required this.onChanged,
  });

  final String title;
  final int value;
  final FocusSessionKind kind;
  final ValueChanged<int> onChanged;

  @override
  State<_MinutesField> createState() => _MinutesFieldState();
}

class _MinutesFieldState extends State<_MinutesField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MinutesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变了就同步过来，但**正在报错时不覆盖**：那会抹掉用户刚敲进去的
    // 那个越界数字，让他没法看清自己打的是什么。
    if (widget.value != oldWidget.value && _error == null) {
      _controller.text = '${widget.value}';
    }
  }

  void _handle(String text) {
    final int? parsed = int.tryParse(text.trim());
    final String? error = parsed == null
        ? '请填一个整数。'
        : validateMinutes(parsed, widget.kind);
    setState(() => _error = error);
    if (parsed != null && error == null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final ({int min, int max}) range = minutesRangeFor(widget.kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(widget.title),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: '分钟',
                helperText: '${range.min}–${range.max}',
                errorText: _error,
                isDense: true,
              ),
              onChanged: _handle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? description = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.bodyLarge),
          if (description != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ),
    );
  }
}
