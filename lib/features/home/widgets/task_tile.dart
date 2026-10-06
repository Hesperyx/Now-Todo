import 'package:flutter/material.dart';

import '../../../core/models/entities.dart';
import '../../../core/models/enum_labels.dart';
import '../../../core/models/enums.dart';
import '../../../core/utils/time.dart';

/// 列表里的一条任务。
///
/// 刻意不用 `ListTile`：一条任务最多要显示四类信息（备注、截止时间、
/// 优先级、子任务进度、标签），全塞进 `ListTile.subtitle` 会打架。
/// 自己搭 `Row + Column`，多几行代码，换来的是想调哪里就调哪里。
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.nowMillis,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    super.key,
  });

  final TodoTask task;

  /// 这一帧的「现在」。由列表统一传入，保证同一屏里所有任务用同一个基准，
  /// 也方便测试里固定时间。
  final int nowMillis;

  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool overdue = task.isOverdue(nowMillis);

    return Dismissible(
      key: ValueKey<String>('task-dismiss-${task.id}'),
      // 只允许从右往左划。左右都能划时，滚动手势和删除手势会互相误触。
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(color: theme.colorScheme.errorContainer),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 用 Checkbox 而不是 IconButton：勾选是这一行最高频的操作，
              // 需要足够的点击热区，也需要系统自带的语义与可访问性。
              Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) => onToggle(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    Text(
                      task.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (task.note case final String note
                        when note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _MetaRow(task: task, overdue: overdue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 标题下面那一条小字：截止时间 · 优先级 · 子任务进度 · 标签。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.task, required this.overdue});

  final TodoTask task;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<Widget> chips = <Widget>[];

    if (task.dueDate case final int due) {
      chips.add(
        _Meta(
          icon: task.dueDateHasTime ? Icons.schedule : Icons.event,
          text: task.dueDateHasTime ? formatDateTime(due) : formatDate(due),
          color: overdue ? scheme.error : scheme.onSurfaceVariant,
          emphasize: overdue,
        ),
      );
    }

    if (task.priority != TaskPriority.none) {
      chips.add(
        _Meta(
          icon: Icons.flag_outlined,
          text: task.priority.label,
          color: _priorityColor(scheme, task.priority),
        ),
      );
    }

    if (task.subtaskTotal > 0) {
      chips.add(
        _Meta(
          icon: Icons.checklist_outlined,
          text: '${task.subtaskDone}/${task.subtaskTotal}',
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    if (task.isRepeating) {
      chips.add(
        _Meta(icon: Icons.repeat, text: '重复', color: scheme.onSurfaceVariant),
      );
    }

    for (final String tag in task.tagNames) {
      chips.add(
        _Meta(
          icon: Icons.label_outline,
          text: tag,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // 用 Wrap 而不是 Row：标签多的时候要换行，而不是溢出报错。
    return Wrap(spacing: 12, runSpacing: 2, children: chips);
  }

  /// 优先级的颜色从主题里取，不写死。
  ///
  /// 这样深色模式下不需要另配一套色值，`ColorScheme` 会自动给出
  /// 在那个背景下可读的对比度。
  static Color _priorityColor(ColorScheme scheme, TaskPriority priority) {
    return switch (priority) {
      TaskPriority.none => scheme.outline,
      TaskPriority.low => scheme.tertiary,
      TaskPriority.medium => scheme.primary,
      TaskPriority.high => scheme.error,
    };
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    required this.color,
    this.emphasize = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: emphasize ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
