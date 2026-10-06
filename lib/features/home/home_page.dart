import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/models/task_query.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/task_repository.dart';
import 'widgets/task_empty_state.dart';
import 'widgets/task_tile.dart';

/// 首页：任务列表。
///
/// 这一屏是应用的主干，所以它承担三件事：选视图（今天 / 全部 / 已完成）、
/// 筛（搜索、逾期）、改（勾选完成、划走删除、点进编辑）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _search = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        // 关掉搜索框就把条件一起清掉。留着看不见的筛选条件，
        // 是「列表怎么是空的」这类问题的头号来源。
        _search.clear();
        ref.read(taskQueryProvider.notifier).setSearch(null);
      }
    });
  }

  Future<void> _toggleCompleted(TodoTask task, bool completed) async {
    try {
      await ref.read(taskRepositoryProvider).setCompleted(task.id, completed);
    } on Object catch (error) {
      _report('没能保存：$error');
    }
  }

  /// 划走删除，并给一次撤销机会。
  ///
  /// 待办应用里删错一条任务的代价很高（重新想起来要写什么比写一遍更累），
  /// 所以这里不做二次确认弹窗——那会打断连续删除——而是删完给撤销。
  Future<void> _delete(TodoTask task) async {
    final TaskRepository repo = ref.read(taskRepositoryProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await repo.delete(task.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已删除「${task.title}」'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () {
                repo.restore(task);
              },
            ),
          ),
        );
    } on Object catch (error) {
      _report('没能删除：$error');
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskQuery query = ref.watch(taskQueryProvider);
    final TaskQueryNotifier notifier = ref.read(taskQueryProvider.notifier);
    final AsyncValue<List<TodoTask>> tasks = ref.watch(tasksProvider);
    final int now = nowUtcMillis();

    final bool filtered =
        query.normalizedSearch != null ||
        query.listId != null ||
        query.tagName != null ||
        query.overdueOnly;

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: '搜索标题或备注',
                  border: InputBorder.none,
                ),
                onChanged: notifier.setSearch,
              )
            : const Text(AppConstants.appName),
        actions: <Widget>[
          IconButton(
            tooltip: _searchOpen ? '关闭搜索' : '搜索',
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          PopupMenuButton<TaskSort>(
            tooltip: '排序方式',
            icon: const Icon(Icons.sort),
            initialValue: query.sort,
            onSelected: notifier.setSort,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<TaskSort>>[
              for (final TaskSort sort in TaskSort.values)
                PopupMenuItem<TaskSort>(
                  value: sort,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        sort == query.sort
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(sort.label),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (String value) {
              switch (value) {
                case 'settings':
                  context.push(AppRoutes.settings);
                case 'about':
                  context.push(AppRoutes.about);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'settings', child: Text('设置')),
                  PopupMenuItem<String>(value: 'about', child: Text('关于')),
                ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTheme.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SegmentedButton<DefaultView>(
                        showSelectedIcon: false,
                        segments: <ButtonSegment<DefaultView>>[
                          for (final DefaultView view in DefaultView.values)
                            ButtonSegment<DefaultView>(
                              value: view,
                              label: Text(view.label),
                            ),
                        ],
                        selected: <DefaultView>{
                          TaskQueryNotifier.viewOf(query),
                        },
                        onSelectionChanged: (Set<DefaultView> selection) =>
                            notifier.selectView(selection.first),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('逾期'),
                      selected: query.overdueOnly,
                      onSelected: (_) => notifier.toggleOverdueOnly(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTheme.contentMaxWidth,
                ),
                child: tasks.when(
                  skipLoadingOnRefresh: true,
                  data: (List<TodoTask> items) => items.isEmpty
                      ? TaskEmptyState(
                          filtered: filtered,
                          onClearFilters: notifier.reset,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final TodoTask task = items[index];
                            return TaskTile(
                              task: task,
                              nowMillis: now,
                              onToggle: (bool value) {
                                _toggleCompleted(task, value);
                              },
                              onDelete: () {
                                _delete(task);
                              },
                              onTap: () =>
                                  context.push(AppRoutes.taskDetail(task.id)),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '读不到任务列表：$error',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.taskNew),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
    );
  }
}
