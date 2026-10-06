import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/entities.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/entity_palette.dart';
import '../../data/repositories/organization_repository.dart';
import 'name_color_dialog.dart';

/// 清单管理页。
///
/// 清单回答的是「这件事属于哪一摊」，所以这一页只做四件事：建、改名、
/// 换色、排顺序，加上删除。**任务本身不在这里管**——点一条清单就带着
/// 这个条件回首页，看任务的界面只有一个。
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TodoList>> lists = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('清单')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建清单'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: lists.when(
            skipLoadingOnRefresh: true,
            data: (List<TodoList> items) => items.isEmpty
                ? const _EmptyLists()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    onReorder: (int from, int to) =>
                        _reorder(ref, from, to, items),
                    itemBuilder: (BuildContext context, int index) {
                      final TodoList list = items[index];
                      return _ListTile(
                        // key 不能省：没有它拖拽之后会把内容串行。
                        key: ValueKey<String>(list.id),
                        list: list,
                        onOpen: () => _open(context, ref, list),
                        onRename: () => _rename(context, ref, list),
                        onDelete: () => _delete(context, ref, list),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '读不到清单：$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final NameColorResult? result = await showNameColorDialog(
      context,
      title: '新建清单',
      hint: '比如：工作',
      emptyMessage: '清单名不能是空的',
    );
    if (result == null || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(listRepositoryProvider)
          .create(result.name, color: result.color);
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能新建：$error')));
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    TodoList list,
  ) async {
    final NameColorResult? result = await showNameColorDialog(
      context,
      title: '编辑清单',
      hint: '比如：工作',
      emptyMessage: '清单名不能是空的',
      initialName: list.name,
      initialColor: list.color,
    );
    if (result == null || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ListRepository repo = ref.read(listRepositoryProvider);
    try {
      if (result.name != list.name) {
        await repo.rename(list.id, result.name);
      }
      if (result.color != list.color) {
        await repo.setColor(list.id, result.color);
      }
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能保存：$error')));
    }
  }

  /// 删除前先把「里面的任务会怎样」说清楚。
  ///
  /// 这是整个功能里唯一一处不可逆且影响别人的动作：用户点删除时心里想的
  /// 是「这个分类不要了」，如果任务跟着一起没了，那是灾难。
  /// 弹窗里那句「不会跟着被删掉」不是客套话，是这个按钮能不能按的前提。
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TodoList list,
  ) async {
    final int count = list.pendingCount;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('删除「${list.name}」？'),
        content: Text(
          count == 0 ? '这个清单里没有未完成的任务。' : '里面的 $count 条未完成任务不会被删掉，它们会回到未分类。',
        ),
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
    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TaskQueryNotifier query = ref.read(taskQueryProvider.notifier);
    // 正在按这条清单筛选时把它清掉，否则删完会看到一个空列表，
    // 而空列表的原因（条件指向一个已不存在的清单）在界面上看不出来。
    if (ref.read(taskQueryProvider).listId == list.id) query.setList(null);
    try {
      final bool removed = await ref
          .read(listRepositoryProvider)
          .delete(list.id);
      if (!removed) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('收件箱是内置的，不能删除。')));
      }
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能删除：$error')));
    }
  }

  /// 带着这条清单回首页。
  void _open(BuildContext context, WidgetRef ref, TodoList list) {
    ref.read(taskQueryProvider.notifier).setList(list.id);
    if (context.canPop()) context.pop();
  }

  Future<void> _reorder(
    WidgetRef ref,
    int from,
    int to,
    List<TodoList> items,
  ) async {
    final List<String> ids = <String>[
      for (final TodoList list in items) list.id,
    ];
    // ReorderableListView 给的 to 是「移走之前」的目标下标，
    // 往后拖时要减一，否则每拖一次都会少一位。
    final int target = to > from ? to - 1 : to;
    ids.insert(target, ids.removeAt(from));
    await ref.read(listRepositoryProvider).reorder(ids);
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.list,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final TodoList list;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? color = EntityPalette.resolve(list.color);

    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.outlineVariant,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(list.name),
      subtitle: Text(
        list.pendingCount == 0 ? '没有待办' : '${list.pendingCount} 条待办',
      ),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: '清单操作',
        onSelected: (String value) {
          switch (value) {
            case 'rename':
              onRename();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'rename',
            child: Text('重命名 / 换颜色'),
          ),
          if (list.isBuiltIn)
            const PopupMenuItem<String>(enabled: false, child: Text('内置清单不能删除'))
          else
            const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}

class _EmptyLists extends StatelessWidget {
  const _EmptyLists();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.folder_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('清单是空的', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // 内置的收件箱由 `ensureInitialized()` 保证存在，所以清单列表
            // 正常不可能为空。真走到这里说明初始化没跑完——与其编一句
            // 「还没有清单」，不如把这条线索留给用户。
            Text(
              '内置的收件箱应该一直在。看不到它，说明数据库初始化没跑完。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
