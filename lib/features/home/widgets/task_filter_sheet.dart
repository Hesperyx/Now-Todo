import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/entities.dart';
import '../../../core/models/enum_labels.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/task_query.dart';
import '../../../core/theme/entity_palette.dart';

/// 打开筛选面板。
///
/// 做成底部弹层而不是塞进首页顶部的一排 chip：清单和标签的数量是用户自己
/// 长出来的（几十个很正常），摊在首页上会把列表挤到看不见。
/// 首页只留「已经生效的条件」和「逾期」这个最常用的一个。
Future<void> showTaskFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const _TaskFilterSheet(),
  );
}

class _TaskFilterSheet extends ConsumerWidget {
  const _TaskFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TaskQuery query = ref.watch(taskQueryProvider);
    final TaskQueryNotifier notifier = ref.read(taskQueryProvider.notifier);
    // 还没读到时不挡住界面：弹层里的选项少几个比转圈圈好，
    // 而且这些流本来就读得极快（本地库，无网络）。
    final List<TodoList> lists =
        ref.watch(listsProvider).valueOrNull ?? const <TodoList>[];
    final List<TodoTag> tags =
        ref.watch(tagsProvider).valueOrNull ?? const <TodoTag>[];

    return SafeArea(
      child: ConstrainedBox(
        // 弹层最高占屏幕的八成，剩下的留给用户看见「上面还有个列表」。
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('筛选', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    // 没有条件可清时置灰而不是藏起来：按钮突然出现又消失，
                    // 比一直看得见但要等一会儿才能按更让人困惑。
                    onPressed: query.hasFilters ? notifier.clearFilters : null,
                    child: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Section(
                title: '清单',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('不限'),
                      selected: query.listId == null,
                      onSelected: (_) => notifier.setList(null),
                    ),
                    for (final TodoList list in lists)
                      ChoiceChip(
                        avatar: list.color == null
                            ? null
                            : _Dot(color: EntityPalette.resolve(list.color)!),
                        label: Text(list.name),
                        selected: query.listId == list.id,
                        onSelected: (_) => notifier.setList(
                          query.listId == list.id ? null : list.id,
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: '标签',
                child: tags.isEmpty
                    ? _Hint(text: '还没有标签。在任务里写一个标签名，它就出现在这里。')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text('不限'),
                            selected: query.tagName == null,
                            onSelected: (_) => notifier.setTag(null),
                          ),
                          for (final TodoTag tag in tags)
                            ChoiceChip(
                              avatar: tag.color == null
                                  ? null
                                  : _Dot(
                                      color: EntityPalette.resolve(tag.color)!,
                                    ),
                              label: Text(tag.name),
                              selected: query.tagName == tag.name,
                              onSelected: (_) => notifier.setTag(
                                query.tagName == tag.name ? null : tag.name,
                              ),
                            ),
                        ],
                      ),
              ),
              _Section(
                title: '优先级',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final TaskPriority priority in TaskPriority.values)
                      FilterChip(
                        label: Text(priority.label),
                        selected: query.priorities.contains(priority),
                        onSelected: (_) => notifier.togglePriority(priority),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Hint(text: '筛选只影响首页看到的任务，不会改动任务本身。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 清单 / 标签前面的颜色点。
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
