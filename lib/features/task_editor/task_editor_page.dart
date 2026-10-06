import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/recurrence/recurrence_rule.dart';
import '../../core/recurrence/recurrence_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/task_repository.dart';
import 'widgets/recurrence_sheet.dart';

/// 任务编辑页。`taskId == null` 时是新建。
///
/// 分成「取数据」和「编辑表单」两个 Widget，是因为表单要有自己的
/// `initState` 来灌初值。如果直接在 `build` 里判断「第一次拿到数据就
/// setState」，会在构建期间改状态，Flutter 会直接抛异常。
class TaskEditorPage extends ConsumerWidget {
  const TaskEditorPage({this.taskId, super.key});

  final String? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = taskId;
    if (id == null) {
      return const _TaskEditorForm(task: null);
    }

    final AsyncValue<TodoTask?> task = ref.watch(taskByIdProvider(id));
    return task.when(
      data: (TodoTask? value) => value == null
          ? const _MissingTaskScaffold()
          : _TaskEditorForm(key: ValueKey<String>(value.id), task: value),
      loading: () => const _LoadingScaffold(),
      error: (Object error, StackTrace stack) => _LoadingScaffold(error: error),
    );
  }
}

class _MissingTaskScaffold extends StatelessWidget {
  const _MissingTaskScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任务')),
      body: const Center(child: Text('这条任务已经不存在了。')),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final Object? message = error;
    return Scaffold(
      appBar: AppBar(title: const Text('任务')),
      body: Center(
        child: message == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$message', textAlign: TextAlign.center),
              ),
      ),
    );
  }
}

class _TaskEditorForm extends ConsumerStatefulWidget {
  const _TaskEditorForm({required this.task, super.key});

  /// `null` = 新建。
  final TodoTask? task;

  @override
  ConsumerState<_TaskEditorForm> createState() => _TaskEditorFormState();
}

class _TaskEditorFormState extends ConsumerState<_TaskEditorForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _tagInput = TextEditingController();

  int? _dueDate;
  bool _dueDateHasTime = false;
  TaskPriority _priority = TaskPriority.none;
  String? _listId;
  final List<String> _tags = <String>[];
  bool _busy = false;

  /// 重复规则的草稿。`null` = 不重复。
  ///
  /// 规则不在 `TodoTask` 里（任务只记一个 `recurrenceRuleId`），所以它有
  /// 自己的装载过程：改这条任务的规则要先把整条规则读出来。
  RecurrenceRule? _recurrence;

  /// 刚从库里读出来的规则，用来判断「重复设置被动过没有」。
  ///
  /// 不能拿 [_recurrence] 自己跟自己比——它是被弹窗改过的那个。
  RecurrenceRule? _originalRule;

  /// 规则读完了没有。没有规则要读时一开始就是 `true`。
  ///
  /// 保存按钮在它为 `false` 时是灰的：规则还没读回来就把表单存下去，
  /// 会把用户已有的规则当成「草稿是 null」删掉。
  bool _ruleReady = true;

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final TodoTask? task = widget.task;
    if (task == null) return;
    _title.text = task.title;
    _note.text = task.note ?? '';
    _dueDate = task.dueDate;
    _dueDateHasTime = task.dueDateHasTime;
    _priority = task.priority;
    _listId = task.listId;
    _tags.addAll(task.tagNames);
    if (task.recurrenceRuleId != null) {
      _ruleReady = false;
      unawaited(_loadRecurrence(task.id));
    }
  }

  Future<void> _loadRecurrence(String taskId) async {
    try {
      final RecurrenceRule? rule = await ref
          .read(recurrenceRepositoryProvider)
          .findForTask(taskId);
      if (!mounted) return;
      setState(() {
        _recurrence = rule;
        _originalRule = rule;
        _ruleReady = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      // 读失败就继续当「不重复」处理太危险了——那会在保存时把规则删掉。
      // 保持 `_ruleReady = false`，保存按钮继续灰着，用户看得见原因。
      _report('没能读取重复规则：$error');
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  // ───────────────────────────── 表单动作 ─────────────────────────────

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _dueDate == null
        ? now
        : fromUtcMillis(_dueDate!).toLocal();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() {
      // 只选日期时存「本地当天的起点」。存 `picked` 的毫秒会造成
      // 跨时区后日期漂移一天，见 lib/core/utils/time.dart。
      _dueDate = dayOnlyMillis(picked);
      _dueDateHasTime = false;
    });
  }

  Future<void> _pickTime() async {
    final DateTime base = _dueDate == null
        ? DateTime.now()
        : fromUtcMillis(_dueDate!).toLocal();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      ).utcMillis;
      _dueDateHasTime = true;
    });
  }

  void _clearDueDate() {
    final bool hadRule = _recurrence != null;
    setState(() {
      _dueDate = null;
      _dueDateHasTime = false;
      // 重复是靠截止日期推算的：没有日期，「下一次」无从谈起。
      // 与其留一条算不出下次的规则，不如一起清掉并说清楚。
      _recurrence = null;
    });
    if (hadRule) _report('去掉截止日期，重复也就一起取消了。');
  }

  // ──────────────────────────── 重复 ────────────────────────────

  /// 打开重复设置弹窗。返回后把草稿写进状态。
  Future<void> _editRecurrence() async {
    if (_dueDate == null) {
      // 先补一个日期，再进弹窗：弹窗里的预览要有东西可算。
      // 用「今天」而不是「此刻」，日期化的任务不该凭空多出一个时刻。
      setState(() {
        _dueDate = dayOnlyMillis(DateTime.now());
        _dueDateHasTime = false;
      });
      _report('重复的任务要有截止日期，已经设成今天。');
    }

    final RecurrenceRule? next = await showRecurrenceSheet(
      context,
      initial: _recurrence,
      anchor: fromUtcMillis(_dueDate!).toLocal(),
    );
    if (next == null || !mounted) return;
    setState(() => _recurrence = next);
  }

  /// 草稿规则：锚点永远跟着当前的截止日期走。
  ///
  /// 「此后全部」改的就是这个锚点；「仅此一次」会让仓储把旧锚点原样放回去
  /// （[RecurrenceRepository.apply] 的 `keepSeriesAnchor`）。
  RecurrenceRule _draftRule(RecurrenceRule draft) =>
      draft.copyWith(startsOn: fromUtcMillis(_dueDate!).toLocal());

  /// 两条规则的「设置」是否一致。
  ///
  /// 锚点不参与比较：草稿的锚点跟着截止日期走，用户没动重复设置时两者
  /// 天然不同，拿它比会让每次保存都弹一次「仅此一次 / 此后全部」。
  bool _sameRule(RecurrenceRule? a, RecurrenceRule? b) {
    if (a == null || b == null) return a == b;
    return a.copyWith(startsOn: b.startsOn) == b;
  }

  /// 改动要只落在这一条，还是让整个系列以后都按新的走。
  ///
  /// 返回 `null` = 用户取消（保存整个中止）。只有日期或重复设置被改动时
  /// 才需要问——标题、备注、优先级本来就由下一条从这一条复制过去，
  /// 不存在「只影响这一次」的歧义。
  Future<bool?> _askScope() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('改动应用到哪？'),
        content: const Text(
          '这条任务属于一个重复系列。\n\n'
          '「仅此一次」只改这一条的日期与设置，系列仍按原来的节奏往前走。\n'
          '「此后全部」会把系列的时间基准挪到新的日期，后面的都跟着变。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('仅此一次'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('此后全部'),
          ),
        ],
      ),
    );
  }

  void _addTag(String raw) {
    final String name = raw.trim();
    if (name.isEmpty) return;
    if (_tags.contains(name)) {
      _tagInput.clear();
      return;
    }
    setState(() {
      _tags.add(name);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      _report('标题不能为空');
      return;
    }
    if (!_ruleReady) {
      // 兜一道：按钮这时是灰的，但键盘上的「完成」与自动提交绕得过按钮。
      _report('重复规则还没读完，稍等一下再存。');
      return;
    }

    // 改动只落这一条，还是让整个系列以后都跟着变。只有日期或重复设置
    // 被动过才需要问，所以默认是「此后全部」（新建时唯一说得通的解释）。
    bool seriesWide = true;
    if (!_isNew) {
      final bool touched =
          _dueDate != widget.task!.dueDate ||
          !_sameRule(_recurrence, _originalRule);
      if (touched && (_recurrence != null || _originalRule != null)) {
        final bool? answer = await _askScope();
        // 用户取消 = 整个保存中止：他点的是「我再想想」，不是「按默认存」。
        if (answer == null) return;
        seriesWide = answer;
        if (!mounted) return;
      }
    }

    setState(() => _busy = true);
    final TaskRepository repo = ref.read(taskRepositoryProvider);
    final String note = _note.text.trim();

    try {
      final String id;
      if (_isNew) {
        // 新建时先落规则再落任务：任务行要带上规则的 id。两条写入不在
        // 一个事务里——规则没被引用就是一条孤儿行，比任务指向不存在的
        // 规则安全得多。
        final RecurrenceRule? draft = _recurrence;
        final String? ruleId = draft == null
            ? null
            : await ref
                  .read(recurrenceRepositoryProvider)
                  .create(_draftRule(draft));
        id = await repo.create(
          title: title,
          note: note.isEmpty ? null : note,
          dueDate: _dueDate,
          dueDateHasTime: _dueDateHasTime,
          priority: _priority,
          listId: _listId,
          recurrenceRuleId: ruleId,
        );
      } else {
        id = widget.task!.id;
        final RecurrenceRule? draft = _recurrence;
        // 「仅此一次」靠 keepSeriesAnchor 把锚点原样放回去：被挪过的这一条
        // 会在下次推进时被 occurrenceOnOrBefore 吸回原来的节奏。
        final String? ruleId = await ref
            .read(recurrenceRepositoryProvider)
            .apply(
              taskId: id,
              draft: draft == null ? null : _draftRule(draft),
              keepSeriesAnchor: !seriesWide,
            );
        await repo.update(
          id,
          title: title,
          note: note.isEmpty ? null : note,
          dueDate: _dueDate,
          dueDateHasTime: _dueDateHasTime,
          priority: _priority,
          listId: _listId,
          recurrenceRuleId: ruleId,
        );
      }
      // 标签单独写：它跨两张表，放进 create/update 会让那两个方法
      // 不得不承担事务边界，而调用方未必想要。
      await repo.setTaskTags(id, _tags);

      if (!mounted) return;
      context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _report('没能保存：$error');
    }
  }

  Future<void> _confirmDelete() async {
    final TodoTask? task = widget.task;
    if (task == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除这条任务？'),
        content: const Text('任务、它的子任务和标签关联都会一起删掉，无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final TaskRepository repo = ref.read(taskRepositoryProvider);
    try {
      await repo.delete(task.id);
      if (!mounted) return;
      context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      _report('没能删除：$error');
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────────────────────── 构建 ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TodoList> lists =
        ref.watch(listsProvider).valueOrNull ?? const <TodoList>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建任务' : '编辑任务'),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              // 从这里进专注页会把 taskId 带过去，计时一开始就挂在这条任务上——
              // 让用户先开计时再自己回头去找任务，是最容易忘的一步。
              tooltip: '开始专注',
              icon: const Icon(Icons.timer_outlined),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.focusFor(widget.task!.id)),
            ),
          if (!_isNew)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: <Widget>[
              TextField(
                controller: _title,
                autofocus: _isNew,
                textInputAction: TextInputAction.next,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '备注',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              _SectionLabel(text: '截止时间'),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _dueDate == null ? '选择日期' : formatDate(_dueDate!),
                    ),
                    onPressed: _pickDate,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _dueDateHasTime && _dueDate != null
                          ? formatDateTime(_dueDate!)
                          : '加时间',
                    ),
                    onPressed: _dueDate == null ? null : _pickTime,
                  ),
                  const Spacer(),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: '清除截止时间',
                      icon: const Icon(Icons.clear),
                      onPressed: _clearDueDate,
                    ),
                ],
              ),
              const SizedBox(height: 24),

              _SectionLabel(text: '重复'),
              _RecurrenceBlock(
                rule: _recurrence,
                ready: _ruleReady,
                onEdit: _busy ? null : _editRecurrence,
                onClear: _busy
                    ? null
                    : () => setState(() => _recurrence = null),
              ),
              const SizedBox(height: 24),

              _SectionLabel(text: '优先级'),
              SegmentedButton<TaskPriority>(
                showSelectedIcon: false,
                segments: <ButtonSegment<TaskPriority>>[
                  for (final TaskPriority priority in TaskPriority.values)
                    ButtonSegment<TaskPriority>(
                      value: priority,
                      label: Text(priority.label),
                    ),
                ],
                selected: <TaskPriority>{_priority},
                onSelectionChanged: (Set<TaskPriority> selection) =>
                    setState(() => _priority = selection.first),
              ),
              const SizedBox(height: 24),

              _SectionLabel(text: '清单'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  // 「未分类」用 `null` 表示，和数据库里 `list_id IS NULL` 一致。
                  ChoiceChip(
                    label: const Text('未分类'),
                    selected: _listId == null,
                    onSelected: (_) => setState(() => _listId = null),
                  ),
                  for (final TodoList list in lists)
                    ChoiceChip(
                      label: Text(list.name),
                      selected: _listId == list.id,
                      onSelected: (_) => setState(() => _listId = list.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              _SectionLabel(text: '标签'),
              if (_tags.isNotEmpty) ...<Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String tag in _tags)
                      InputChip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _tagInput,
                decoration: const InputDecoration(
                  labelText: '添加标签',
                  helperText: '回车确认。同名标签会自动复用。',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addTag,
              ),

              if (!_isNew) ...<Widget>[
                const SizedBox(height: 24),
                _SectionLabel(text: '子任务'),
                _SubtaskSection(taskId: widget.task!.id),
                const SizedBox(height: 24),
                _SectionLabel(text: '提醒'),
                _ReminderSection(taskId: widget.task!.id),
              ] else ...<Widget>[
                const SizedBox(height: 24),
                Text(
                  '保存之后可以添加子任务与提醒。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      // 这里的 `heightFactor: 1` 不能删。
      //
      // `_ScaffoldLayout.performLayout` 给 bottomNavigationBar 的约束是「宽度定死、
      // 高度放松」（`looseConstraints.tighten(width: size.width)`，
      // `material/scaffold.dart:1044`），并且会把它量出来的高度原样加进
      // `bottomWidgetsHeight`（同文件 `:1058-1062`），再从 body 的最大高度里减掉
      // （`:1097-1103`）。而裸 `Center` 在没有 heightFactor 时会吃满可用高度，
      // 于是底部条变成整屏高、body 被压成 0 高——表单一个像素都显示不出来，
      // 但 AppBar 和保存按钮照常渲染，肉眼极容易漏掉。
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.contentMaxWidth,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                // 规则没读完时禁用：那时 `_recurrence` 还是 null，
                // 存下去就等于把用户的重复规则删掉。
                onPressed: (_busy || !_ruleReady) ? null : _save,
                child: Text(_busy ? '保存中…' : '保存'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 拖拽之后把新顺序写回库里。
///
/// `to` 是「插到哪个位置之前」的语义：往下拖时它已经把被拖走的那一项算进去了，
/// 所以要先减一，否则最后一条永远拖不到末尾。
Future<void> _reorderSubtasks(
  WidgetRef ref,
  int from,
  int to,
  List<TodoSubtask> items,
) async {
  final List<String> ids = <String>[
    for (final TodoSubtask item in items) item.id,
  ];
  ids.insert(to > from ? to - 1 : to, ids.removeAt(from));
  await ref.read(taskRepositoryProvider).reorderSubtasks(ids);
}

/// 子任务区块。
///
/// 只支持一层：`subtasks` 表没有 `parent_id`。两层以上子任务会让
/// 「完成进度」怎么算都说不清楚，PRD 也没要求。
class _SubtaskSection extends ConsumerWidget {
  const _SubtaskSection({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TodoSubtask>> subtasks = ref.watch(
      subtasksProvider(taskId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        subtasks.when(
          skipLoadingOnRefresh: true,
          data: (List<TodoSubtask> items) => items.isEmpty
              ? Text(
                  '还没有子任务。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : ReorderableListView(
                  // 编辑器自己就是一个滚动视图，这里再套一个会抢走拖拽手势，
                  // 所以列表只负责排布，滚动交给外面。
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (int from, int to) =>
                      _reorderSubtasks(ref, from, to, items),
                  children: <Widget>[
                    for (final TodoSubtask item in items)
                      CheckboxListTile(
                        key: ValueKey<String>(item.id),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: item.isDone,
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        secondary: IconButton(
                          tooltip: '删除子任务',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(taskRepositoryProvider)
                              .deleteSubtask(item.id),
                        ),
                        onChanged: (bool? value) => ref
                            .read(taskRepositoryProvider)
                            .setSubtaskDone(item.id, value ?? false),
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text('读不到子任务：$error'),
        ),
        const SizedBox(height: 8),
        _SubtaskInput(taskId: taskId),
      ],
    );
  }
}

class _SubtaskInput extends ConsumerStatefulWidget {
  const _SubtaskInput({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_SubtaskInput> createState() => _SubtaskInputState();
}

class _SubtaskInputState extends ConsumerState<_SubtaskInput> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final String title = raw.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskRepositoryProvider).addSubtask(widget.taskId, title);
      _controller.clear();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能添加：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        labelText: '添加子任务',
        border: OutlineInputBorder(),
      ),
      onSubmitted: _submit,
    );
  }
}

/// 提醒区块。
///
/// 这里只负责往库里写。真正把提醒排进系统的是 `ReminderScheduler`——
/// 它监听整张表，写完自动重算，界面不需要调任何「排一下提醒」的方法。
/// 这条分界是刻意的：如果界面自己排通知，应用被强杀后重启就没人补排，
/// 而「重启后提醒不再响」是用户完全察觉不到的那类故障。
class _ReminderSection extends ConsumerWidget {
  const _ReminderSection({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TodoReminder>> reminders = ref.watch(
      remindersProvider(taskId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        reminders.when(
          skipLoadingOnRefresh: true,
          data: (List<TodoReminder> items) => items.isEmpty
              ? Text(
                  '还没有提醒。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final TodoReminder item in items)
                      _ReminderTile(reminder: item),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text('读不到提醒：$error'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add_alarm, size: 18),
            label: const Text('添加提醒'),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await _pickDateTime(
      context,
      initial: now.add(const Duration(hours: 1)),
    );
    if (!context.mounted || picked == null) return;

    // 一次性提醒排在过去等于永远不响。这不是「稍后会响」，是静默失效，
    // 所以必须当场拦住——让它进库，用户只会以为提醒功能坏了。
    if (!picked.isAfter(now)) {
      _showToast(context, '这个时间已经过去了，换一个吧。');
      return;
    }

    try {
      await ref
          .read(reminderRepositoryProvider)
          .add(taskId: taskId, remindAt: picked.utcMillis);
    } on Object catch (error) {
      if (!context.mounted) return;
      _showToast(context, '没能添加提醒：$error');
    }
  }
}

/// 单条提醒。
class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final TodoReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Switch(
        value: reminder.enabled,
        onChanged: (bool value) => ref
            .read(reminderRepositoryProvider)
            .update(reminder.id, enabled: value),
      ),
      title: Text(
        formatDateTime(reminder.remindAt),
        style: TextStyle(
          color: reminder.enabled ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        reminder.repeatType.label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: '改重复方式',
            icon: const Icon(Icons.repeat, size: 18),
            onPressed: () => _pickRepeat(context, ref),
          ),
          IconButton(
            tooltip: '删除提醒',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                ref.read(reminderRepositoryProvider).delete(reminder.id),
          ),
        ],
      ),
      onTap: () => _pickTime(context, ref),
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final DateTime? picked = await _pickDateTime(
      context,
      initial: fromUtcMillis(reminder.remindAt),
    );
    if (!context.mounted || picked == null) return;
    await ref
        .read(reminderRepositoryProvider)
        .update(reminder.id, remindAt: picked.utcMillis);
  }

  Future<void> _pickRepeat(BuildContext context, WidgetRef ref) async {
    final ReminderRepeatType? picked = await showDialog<ReminderRepeatType>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('重复方式'),
        children: <Widget>[
          for (final ReminderRepeatType value in ReminderRepeatType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(value),
              child: Row(
                children: <Widget>[
                  Icon(
                    value == reminder.repeatType
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(value.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (!context.mounted || picked == null) return;
    await ref
        .read(reminderRepositoryProvider)
        .update(reminder.id, repeatType: picked);
  }
}

/// 先选日期再选时间，两步都取消就返回 null。
///
/// `firstDate` 刻意取得很早：编辑一条已经过期的提醒时，
/// `initialDate` 可能早于今天，而 `showDatePicker` 要求它落在区间内。
Future<DateTime?> _pickDateTime(
  BuildContext context, {
  required DateTime initial,
}) async {
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: '选择提醒日期',
  );
  if (date == null || !context.mounted) return null;
  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: '选择提醒时间',
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

void _showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 「重复」那一块：没设置时是一个入口，设好之后是一行摘要加「下一次」。
///
/// 摘要用 [describeRecurrence] 而不是自己拼字符串——同一句话在别处（首页、
/// 以后的通知文案）也要用，各拼一份早晚会对不上。
class _RecurrenceBlock extends StatelessWidget {
  const _RecurrenceBlock({
    required this.rule,
    required this.ready,
    required this.onEdit,
    required this.onClear,
  });

  final RecurrenceRule? rule;
  final bool ready;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.repeat),
        title: Text('正在读取重复设置…'),
        subtitle: Text('读完之前不能保存，免得把已有的设置冲掉。'),
      );
    }

    final RecurrenceRule? current = rule;
    if (current == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.repeat),
        title: const Text('不重复'),
        subtitle: const Text('设置之后，完成这一条会自动生成下一条。'),
        trailing: TextButton(onPressed: onEdit, child: const Text('设置重复')),
        onTap: onEdit,
      );
    }

    final String? next = nextOccurrenceText(current, now: DateTime.now());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.repeat),
      title: Text(describeRecurrence(current)),
      subtitle: Text(next == null ? '按当前设置没有下一次了。' : '下一次：$next'),
      trailing: IconButton(
        tooltip: '取消重复',
        icon: const Icon(Icons.close),
        onPressed: onClear,
      ),
      onTap: onEdit,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
