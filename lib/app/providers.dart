import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/entities.dart';
import '../core/models/enums.dart';
import '../core/models/task_query.dart';
import '../data/database/app_database.dart';
import '../data/repositories/organization_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/task_repository.dart';

/// 组合根：唯一知道「谁依赖谁」的地方。
///
/// 界面层只 `ref.watch` 自己需要的那一个 provider，不 new 数据库、
/// 不 new 仓储。这样测试里替换任意一层都只需要一个 `overrideWithValue`。

// ─────────────────────────── 数据库与仓储 ───────────────────────────

/// 全局唯一的数据库实例。
///
/// 用 `Provider` 而不是每次现取，是因为 `AppDatabase` 内部持有查询流缓存，
/// 建第二个实例会让同一张表的两个 stream 各自缓存一份数据。
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
      (Ref ref) => TaskRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ListRepository> listRepositoryProvider =
    Provider<ListRepository>(
      (Ref ref) => ListRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<TagRepository> tagRepositoryProvider = Provider<TagRepository>(
  (Ref ref) => TagRepository(ref.watch(appDatabaseProvider)),
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
    );

// ─────────────────────────────── 偏好 ───────────────────────────────

/// 启动时读到的偏好快照，由 `main()` 覆盖。
///
/// 为什么要单独一个 provider，而不是直接 `ref.watch(preferencesProvider)`：
/// 「默认视图」只在**冷启动那一次**决定首屏筛选条件，之后用户在当前会话里
/// 手动切的视图不该被别的偏好变化（比如改主题）冲掉。
/// 用一次性快照把「初始化」和「实时同步」分开，两个需求互不打架。
final Provider<AppPreferences> initialPreferencesProvider =
    Provider<AppPreferences>((Ref ref) => const AppPreferences());

/// 实时偏好流。主题模式、通知开关用它，改了立刻生效。
final StreamProvider<AppPreferences> preferencesProvider =
    StreamProvider<AppPreferences>(
      (Ref ref) => ref.watch(settingsRepositoryProvider).watch(),
    );

// ─────────────────────────── 任务列表查询 ───────────────────────────

/// 当前列表页的筛选 / 排序条件。
///
/// 放在 provider 里而不是 `StatefulWidget` 的 `setState` 里，
/// 是因为「今天」入口和清单页将来都要复用同一套筛选逻辑。
class TaskQueryNotifier extends Notifier<TaskQuery> {
  @override
  TaskQuery build() {
    // 只在首次构建时读一次启动快照，见 initialPreferencesProvider 的说明。
    final DefaultView view = ref.read(initialPreferencesProvider).defaultView;
    return switch (view) {
      DefaultView.today => const TaskQuery(dueTodayOnly: true),
      DefaultView.all => const TaskQuery(),
      DefaultView.completed => const TaskQuery(showCompleted: true),
    };
  }

  /// 切换顶层视图（今天 / 全部 / 已完成）。
  ///
  /// 这三个视图是互斥的整体视角，所以切过去时把其它条件一并复位——
  /// 否则「从清单 A 切到已完成」会带着上一个页面的清单筛选，
  /// 看到一个空列表。
  void selectView(DefaultView view) {
    state = switch (view) {
      DefaultView.today => const TaskQuery(dueTodayOnly: true),
      DefaultView.all => const TaskQuery(),
      DefaultView.completed => const TaskQuery(showCompleted: true),
    };
  }

  void setSearch(String? text) {
    state = state.copyWith(searchText: text);
  }

  void setSort(TaskSort sort) {
    state = state.copyWith(sort: sort);
  }

  void setList(String? listId) {
    state = state.copyWith(listId: listId);
  }

  void setTag(String? tagName) {
    state = state.copyWith(tagName: tagName);
  }

  void toggleOverdueOnly() {
    state = state.copyWith(overdueOnly: !state.overdueOnly);
  }

  void toggleShowCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }

  /// 回到默认视图。
  void reset() {
    state = const TaskQuery(dueTodayOnly: true);
  }

  /// 当前视图对应哪个顶层 tab。派生出来而不是另存一份 state，
  /// 避免两份状态互相不同步。
  static DefaultView viewOf(TaskQuery query) {
    if (query.showCompleted) return DefaultView.completed;
    if (query.dueTodayOnly && query.listId == null && query.tagName == null) {
      return DefaultView.today;
    }
    return DefaultView.all;
  }
}

final NotifierProvider<TaskQueryNotifier, TaskQuery> taskQueryProvider =
    NotifierProvider<TaskQueryNotifier, TaskQuery>(TaskQueryNotifier.new);

/// 当前条件下的任务列表。查询条件一变，Riverpod 自动换掉订阅。
final StreamProvider<List<TodoTask>> tasksProvider =
    StreamProvider<List<TodoTask>>(
      (Ref ref) =>
          ref.watch(taskRepositoryProvider).watch(ref.watch(taskQueryProvider)),
    );

/// 未完成任务总数。
final StreamProvider<int> pendingCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(taskRepositoryProvider).watchPendingCount(),
);

/// 单个任务的实时视图（编辑页用）。
final StreamProviderFamily<TodoTask?, String> taskByIdProvider =
    StreamProvider.family<TodoTask?, String>(
      (Ref ref, String id) => ref.watch(taskRepositoryProvider).watchSingle(id),
    );

/// 某个任务的子任务。
final StreamProviderFamily<List<TodoSubtask>, String> subtasksProvider =
    StreamProvider.family<List<TodoSubtask>, String>(
      (Ref ref, String taskId) =>
          ref.watch(taskRepositoryProvider).watchSubtasks(taskId),
    );

// ─────────────────────────── 清单与标签 ───────────────────────────

final StreamProvider<List<TodoList>> listsProvider =
    StreamProvider<List<TodoList>>(
      (Ref ref) => ref.watch(listRepositoryProvider).watch(),
    );

final StreamProvider<List<TodoTag>> tagsProvider =
    StreamProvider<List<TodoTag>>(
      (Ref ref) => ref.watch(tagRepositoryProvider).watch(),
    );
