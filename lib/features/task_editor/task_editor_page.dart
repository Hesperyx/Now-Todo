import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/task_repository.dart';

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
    setState(() {
      _dueDate = null;
      _dueDateHasTime = false;
    });
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

    setState(() => _busy = true);
    final TaskRepository repo = ref.read(taskRepositoryProvider);
    final String note = _note.text.trim();

    try {
      final String id;
      if (_isNew) {
        id = await repo.create(
          title: title,
          note: note.isEmpty ? null : note,
          dueDate: _dueDate,
          dueDateHasTime: _dueDateHasTime,
          priority: _priority,
          listId: _listId,
        );
      } else {
        id = widget.task!.id;
        await repo.update(
          id,
          title: title,
          note: note.isEmpty ? null : note,
          dueDate: _dueDate,
          dueDateHasTime: _dueDateHasTime,
          priority: _priority,
          listId: _listId,
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
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '保存中…' : '保存'),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
              : Column(
                  children: <Widget>[
                    for (final TodoSubtask item in items)
                      CheckboxListTile(
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
