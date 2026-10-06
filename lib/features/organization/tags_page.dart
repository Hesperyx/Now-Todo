import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/entities.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/entity_palette.dart';
import '../../data/repositories/organization_repository.dart';
import 'name_color_dialog.dart';

/// 标签管理页。
///
/// 标签回答的是「这件事是什么」，跨清单，所以这里没有排序——顺序按名字，
/// 用户自己排出来的顺序在两个页面里长得一样才怪。新建的入口不止这里：
/// 在任务里直接敲一个标签名也会把它建出来，两个入口共用同一张表。
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TodoTag>> tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('标签')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建标签'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: tags.when(
            skipLoadingOnRefresh: true,
            data: (List<TodoTag> items) => items.isEmpty
                ? const _EmptyTags()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TodoTag tag = items[index];
                      return _TagTile(
                        tag: tag,
                        onOpen: () => _open(context, ref, tag),
                        onEdit: () => _edit(context, ref, tag),
                        onDelete: () => _delete(context, ref, tag),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '读不到标签：$error',
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
      title: '新建标签',
      hint: '比如：紧急',
      emptyMessage: '标签名不能是空的',
    );
    if (result == null || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(tagRepositoryProvider)
          .create(result.name, color: result.color);
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能新建：$error')));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, TodoTag tag) async {
    final NameColorResult? result = await showNameColorDialog(
      context,
      title: '编辑标签',
      hint: '比如：紧急',
      emptyMessage: '标签名不能是空的',
      initialName: tag.name,
      initialColor: tag.color,
    );
    if (result == null || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TagRepository repo = ref.read(tagRepositoryProvider);
    try {
      if (result.name != tag.name) {
        await repo.rename(tag.id, result.name);
      }
      if (result.color != tag.color) {
        await repo.setColor(tag.id, result.color);
      }
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能保存：$error')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoTag tag) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('删除「${tag.name}」？'),
        content: Text(
          tag.taskCount == 0
              ? '还没有任务用过这个标签。'
              : '挂在 ${tag.taskCount} 条任务上的这个标记会被去掉，任务本身不会被删掉。',
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
    // 正在按这个标签筛选时先清掉。留着的话删完就是一片空白，
    // 而首页那条筛选标签写着「标签：xxx」——看起来像页面坏了。
    if (ref.read(taskQueryProvider).tagName == tag.name) {
      ref.read(taskQueryProvider.notifier).setTag(null);
    }
    try {
      await ref.read(tagRepositoryProvider).delete(tag.id);
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('没能删除：$error')));
    }
  }

  void _open(BuildContext context, WidgetRef ref, TodoTag tag) {
    ref.read(taskQueryProvider.notifier).setTag(tag.name);
    if (context.canPop()) context.pop();
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoTag tag;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? color = EntityPalette.resolve(tag.color);

    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.outlineVariant,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(tag.name),
      subtitle: Text(tag.taskCount == 0 ? '还没有任务用过' : '${tag.taskCount} 条任务'),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: '标签操作',
        onSelected: (String value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'edit', child: Text('改名 / 换颜色')),
          PopupMenuItem<String>(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}

class _EmptyTags extends StatelessWidget {
  const _EmptyTags();

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
              Icons.label_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('还没有标签', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '标签可以跨清单。在任务里直接敲一个名字就会建出来，也可以在这里先建好。',
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
