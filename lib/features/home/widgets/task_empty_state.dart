import 'package:flutter/material.dart';

/// 列表为空时的提示。
///
/// 空态是待办应用里出现频率最高的一屏之一（一个新用户全部时间都花在这里），
/// 所以它得说清楚「为什么空」：是真的没有任务，还是筛选条件把任务藏起来了。
/// 这两种情况给同一句「暂无任务」是偷懒。
class TaskEmptyState extends StatelessWidget {
  const TaskEmptyState({
    required this.filtered,
    this.onClearFilters,
    super.key,
  });

  /// 是否处于筛选状态（搜索 / 标签 / 清单 / 逾期）。
  final bool filtered;

  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                filtered
                    ? Icons.filter_alt_off_outlined
                    : Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                filtered ? '没有符合条件的任务' : '这里很干净',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                filtered ? '换个关键词，或者清掉筛选条件。' : '点右下角加一条，或者就这么空着——空着也是一种完成。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (filtered && onClearFilters != null) ...<Widget>[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onClearFilters,
                  child: const Text('清空筛选'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
