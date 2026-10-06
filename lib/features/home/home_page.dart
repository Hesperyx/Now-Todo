import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/focus/focus_timer.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/models/task_query.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/task_repository.dart';
import 'widgets/task_empty_state.dart';
import 'widgets/task_filter_sheet.dart';
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

  /// 只在有专注会话在跑的时候走。首页平时不需要每秒重建。
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void dispose() {
    _ticker?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setTicking(bool ticking) {
    if (ticking && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!ticking && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        // 关掉搜索框就把条件一起清掉。留着看不见的筛选条件，
        // 是「列表怎么是空的」这类问题的头号来源。
        _clearSearch();
      }
    });
  }

  /// 清掉搜索条件。
  ///
  /// 输入框里的字要一起清：只清条件的话，下次打开搜索框会看到上一轮的词
  /// 还在框里，而列表已经不受它影响了——那种不一致比筛选本身更难理解。
  void _clearSearch() {
    _search.clear();
    ref.read(taskQueryProvider.notifier).setSearch(null);
  }

  Future<void> _toggleCompleted(TodoTask task, bool completed) async {
    final TaskRepository repo = ref.read(taskRepositoryProvider);
    try {
      final String? nextId = await repo.setCompleted(task.id, completed);
      if (!mounted || nextId == null) return;

      // 重复任务完成时会另起一条。不说一声的话，用户只会看到「勾掉的任务
      // 还在列表里」——那是这个功能最容易被认为是 bug 的地方。
      final TodoTask? next = await repo.findById(nextId);
      if (!mounted) return;
      final int? due = next?.dueDate;
      _report(due == null ? '下一条已经排好了。' : '下一条：${formatDate(due)}');
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
    final TodoFocusSession? running = ref
        .watch(runningSessionProvider)
        .valueOrNull;
    _setTicking(running != null);
    final int now = nowUtcMillis();

    final bool filtered = query.hasFilters;

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
            tooltip: '专注计时',
            icon: Badge(
              // 有会话在跑时挂一个小点。不写数字：它只有「有 / 没有」两态。
              isLabelVisible:
                  ref.watch(runningSessionProvider).valueOrNull != null,
              smallSize: 8,
              child: const Icon(Icons.timer_outlined),
            ),
            onPressed: () => context.push(AppRoutes.focus),
          ),
          IconButton(
            tooltip: _searchOpen ? '关闭搜索' : '搜索',
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: '筛选',
            icon: Badge(
              // 这里的数字是真的数字（生效了几个条件），所以让它显示出来。
              isLabelVisible: query.filterCount > 0,
              label: Text('${query.filterCount}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showTaskFilterSheet(context),
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
                case 'lists':
                  context.push(AppRoutes.lists);
                case 'tags':
                  context.push(AppRoutes.tags);
                case 'stats':
                  context.push(AppRoutes.stats);
                case 'achievements':
                  context.push(AppRoutes.achievements);
                case 'settings':
                  context.push(AppRoutes.settings);
                case 'about':
                  context.push(AppRoutes.about);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'lists', child: Text('清单')),
                  PopupMenuItem<String>(value: 'tags', child: Text('标签')),
                  PopupMenuItem<String>(value: 'stats', child: Text('专注统计')),
                  PopupMenuItem<String>(
                    value: 'achievements',
                    child: Text('成就徽章'),
                  ),
                  PopupMenuItem<String>(value: 'settings', child: Text('设置')),
                  PopupMenuItem<String>(value: 'about', child: Text('关于')),
                ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (running != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTheme.contentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _ResumeBanner(
                    session: running,
                    now: _now,
                    onTap: () => context.push(AppRoutes.focus),
                  ),
                ),
              ),
            ),
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
          _ActiveFilterBar(onClearSearch: _clearSearch),
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
                          onClearFilters: notifier.clearFilters,
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

/// 已生效的筛选条件，一条一个可删的小标签。
///
/// 只做「显示 + 撤销」，不做「修改」——改条件去筛选面板。这样这条栏永远
/// 是当前事实的投影，不会成为第二个需要维护状态的地方。
/// 条件是空的时候它自己不占高度（返回 `SizedBox.shrink`）。
class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.onClearSearch});

  /// 搜索那条不能自己清：输入框里还有字，得让持有 controller 的页面来清。
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TaskQuery query = ref.watch(taskQueryProvider);
    if (!query.hasFilters) return const SizedBox.shrink();

    final TaskQueryNotifier notifier = ref.read(taskQueryProvider.notifier);
    final String? listId = query.listId;
    final String? listName = listId == null
        ? null
        : _nameOf(
            ref.watch(listsProvider).valueOrNull ?? const <TodoList>[],
            listId,
          );

    final String priorities = <String>[
      for (final TaskPriority p in TaskPriority.values)
        if (query.priorities.contains(p)) p.label,
    ].join('、');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            // 清单被删掉之后 `listName` 会是 null：那时候显示条件本身，
            // 而不是假装没有这个条件——列表是空的，用户得知道为什么。
            if (query.normalizedSearch != null)
              _FilterPill(
                label: '搜索：${query.normalizedSearch}',
                onDeleted: onClearSearch,
              ),
            if (query.listId != null)
              _FilterPill(
                label: '清单：${listName ?? '已删除'}',
                onDeleted: () => notifier.setList(null),
              ),
            if (query.tagName != null)
              _FilterPill(
                label: '标签：${query.tagName}',
                onDeleted: () => notifier.setTag(null),
              ),
            if (priorities.isNotEmpty)
              _FilterPill(
                label: '优先级：$priorities',
                onDeleted: () => notifier.setPriorities(const <TaskPriority>{}),
              ),
            if (query.overdueOnly)
              _FilterPill(label: '逾期', onDeleted: notifier.toggleOverdueOnly),
            TextButton(
              onPressed: notifier.clearFilters,
              child: const Text('清空'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 按 id 找清单名。找不到返回 `null`（清单可能刚被删掉）。
String? _nameOf(List<TodoList> lists, String id) {
  for (final TodoList list in lists) {
    if (list.id == id) return list.name;
  }
  return null;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 16),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 「还有一段计时在跑」的提示条。
///
/// 存在的理由：会话是存在库里的，App 被划掉、被杀掉、重启之后它仍然在跑。
/// 不把这件事说出来的话，用户会以为自己已经关掉了，而统计里会多出一段
/// 他从没打算记录的时长。
class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({
    required this.session,
    required this.now,
    required this.onTap,
  });

  final TodoFocusSession session;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FocusTimerState state = session.toTimerState();
    final Duration? remaining = state.remaining(now);
    final String clock = formatDuration(remaining ?? state.elapsed(now));

    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                state.isPaused ? Icons.pause_circle_outline : Icons.timer,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${session.kind.label}${state.isPaused ? '已暂停' : '进行中'} · $clock',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Text(
                '返回',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
