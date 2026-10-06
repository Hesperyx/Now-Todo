import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/focus/achievements.dart';
import '../core/focus/focus_stats.dart';
import '../core/models/entities.dart';
import '../core/models/enums.dart';
import '../core/models/task_query.dart';
import '../core/notifications/flutter_notification_service.dart';
import '../core/notifications/focus_notification_sync.dart';
import '../core/notifications/notification_service.dart';
import '../core/notifications/reminder_scheduler.dart';
import '../core/notifications/timezone_bootstrap.dart';
// 与 drift 生成的数据类同名（都叫 `RecurrenceRule`），加前缀区分。
import '../core/recurrence/recurrence_rule.dart' as core;
import '../core/utils/time.dart';
import '../core/widget/home_widget_service.dart';
import '../core/widget/home_widget_snapshot.dart';
import '../core/widget/home_widget_sync.dart';
import '../data/backup/backup_file_service.dart';
import '../data/database/app_database.dart';
import '../data/repositories/backup_repository.dart';
import '../data/repositories/focus_session_repository.dart';
import '../data/repositories/organization_repository.dart';
import '../data/repositories/recurrence_repository.dart';
import '../data/repositories/reminder_repository.dart';
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

final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>(
      (Ref ref) => ReminderRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<FocusSessionRepository> focusSessionRepositoryProvider =
    Provider<FocusSessionRepository>(
      (Ref ref) => FocusSessionRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<RecurrenceRepository> recurrenceRepositoryProvider =
    Provider<RecurrenceRepository>(
      (Ref ref) => RecurrenceRepository(ref.watch(appDatabaseProvider)),
    );

/// 导入导出。要设置仓储是因为备份里也有「设置」这一段，
/// 而它只有 `SettingsRepository` 知道怎么写回那张单行表。
final Provider<BackupRepository> backupRepositoryProvider =
    Provider<BackupRepository>(
      (Ref ref) => BackupRepository(
        ref.watch(appDatabaseProvider),
        ref.watch(settingsRepositoryProvider),
      ),
    );

/// 备份文件的读写。测试里换成假的，就不必真去弹文件选择器。
final Provider<BackupFileService> backupFileServiceProvider =
    Provider<BackupFileService>((Ref ref) => const FileBackupService());

/// 备份文件 `app.version` 那一栏写什么。
///
/// 单独做成 provider 有两个理由：它是「设备上下文」而不是页面逻辑，页面不该
/// 自己去问插件；以及读它要走平台通道，Widget 测试里那条通道没有对端，await
/// 会一直挂着——换成 provider 之后测试里覆盖一行就够了。
///
/// 查不到就写空串：备份的可用性不该取决于问不问得到版本号。
final FutureProvider<String> appVersionProvider = FutureProvider<String>((
  Ref ref,
) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } on Object {
    return '';
  }
});

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

  /// 整组替换优先级条件。传空集合 = 不限。
  ///
  /// 每次都给一个新的集合：`TaskQuery` 是不可变的，`==` 又按内容比，
  /// 所以原地 `add` 一个传进来的集合会让「状态变了」这件事不被察觉。
  void setPriorities(Set<TaskPriority> priorities) {
    state = state.copyWith(priorities: Set<TaskPriority>.of(priorities));
  }

  /// 加上或去掉一个优先级。
  void togglePriority(TaskPriority priority) {
    final Set<TaskPriority> next = Set<TaskPriority>.of(state.priorities);
    if (!next.remove(priority)) next.add(priority);
    state = state.copyWith(priorities: next);
  }

  void toggleOverdueOnly() {
    state = state.copyWith(overdueOnly: !state.overdueOnly);
  }

  void toggleShowCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }

  /// 清掉全部筛选条件，保留顶层视图与排序。
  ///
  /// **不是** `reset()`：分段按钮选的是「看哪一批任务」，不是筛选条件。
  /// 用户在「今天」里清筛选，想要的还是一份干净的今天，
  /// 而不是被顺手扔回默认视图——那像是应用替他做了个他没做的决定。
  void clearFilters() {
    state = TaskQuery(
      showCompleted: state.showCompleted,
      dueTodayOnly: state.dueTodayOnly,
      sort: state.sort,
    );
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

/// 未完成任务，不受首页筛选条件影响。
///
/// 选择器要的是「我能挂到哪些任务上」，拿 `tasksProvider` 会跟着搜索框和
/// 清单筛选一起变 —— 用户搜到半截再去选任务，列表就只剩一条了。
final StreamProvider<List<TodoTask>> pendingTasksProvider =
    StreamProvider<List<TodoTask>>(
      (Ref ref) => ref.watch(taskRepositoryProvider).watch(const TaskQuery()),
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

/// 某个任务的重复规则（编辑页用）。没有规则时是 `null`。
final StreamProviderFamily<core.RecurrenceRule?, String>
taskRecurrenceProvider = StreamProvider.family<core.RecurrenceRule?, String>(
  (Ref ref, String taskId) =>
      ref.watch(recurrenceRepositoryProvider).watchForTask(taskId),
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

// ─────────────────────────────── 提醒 ───────────────────────────────

/// 某个任务的提醒，按触发时刻升序。
final StreamProviderFamily<List<TodoReminder>, String> remindersProvider =
    StreamProvider.family<List<TodoReminder>, String>(
      (Ref ref, String taskId) =>
          ref.watch(reminderRepositoryProvider).watchForTask(taskId),
    );

/// 通知平台能力。真实实现只在 Android 上做事，桌面预览与测试里是空操作。
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => FlutterNotificationService());

/// 系统当前的通知权限现状。
///
/// 单独做成 provider 是为了让设置页能 `invalidate` 它——用户从系统设置里
/// 改完权限回到应用，只有重新查一次才会显示成新状态。
final FutureProvider<NotificationPermissionStatus>
notificationPermissionProvider = FutureProvider<NotificationPermissionStatus>((
  Ref ref,
) async {
  final NotificationService service = ref.watch(notificationServiceProvider);
  final bool allowed = await service.areNotificationsEnabled();
  final bool exact = await service.canScheduleExact();
  return NotificationPermissionStatus(
    notificationsAllowed: allowed,
    exactAlarmsAllowed: exact,
  );
});

/// 提醒调度器。
///
/// **谁读它谁负责**：这个 provider 在被创建的那一刻就开始监听库变化，
/// 所以 `main()` 里必须读一次把它拉起来，否则提醒永远不会被排进系统。
/// 反过来，Widget 测试不读它，就不会碰到任何通知平台通道。
final Provider<ReminderScheduler> reminderSchedulerProvider =
    Provider<ReminderScheduler>((Ref ref) {
      final SettingsRepository settings = ref.watch(settingsRepositoryProvider);
      final AppPreferences initial = ref.watch(initialPreferencesProvider);
      final ReminderScheduler scheduler = ReminderScheduler(
        repository: ref.watch(reminderRepositoryProvider),
        notifications: ref.watch(notificationServiceProvider),
        initial: ReminderSettings(
          enabled: initial.notificationsEnabled,
          strong: initial.strongReminders,
        ),
        // 这里直接订阅仓储的 stream，而不是 watch(preferencesProvider)：
        // 后者会让这个 provider 每次偏好变化就整体重建，把调度器的
        // 订阅抖掉，正在排的通知会排一半停下。
        settings: settings
            .watch()
            .map(
              (AppPreferences p) => ReminderSettings(
                enabled: p.notificationsEnabled,
                strong: p.strongReminders,
              ),
            )
            .distinct(),
      );
      scheduler.start();
      ref.onDispose(scheduler.dispose);
      return scheduler;
    });

/// 设备时区变更监听。
///
/// 和调度器一样，创建即生效，所以 `main()` 里必须读一次。
final Provider<TimeZoneWatcher> timeZoneWatcherProvider =
    Provider<TimeZoneWatcher>((Ref ref) {
      final ReminderScheduler scheduler = ref.watch(reminderSchedulerProvider);
      final TimeZoneWatcher watcher = TimeZoneWatcher(
        onChanged: (String identifier) async {
          debugPrint('设备时区已变为 $identifier，重排提醒');
          await scheduler.refresh();
        },
      );
      watcher.start();
      ref.onDispose(watcher.dispose);
      return watcher;
    });

// ─────────────────────────────── 专注 ───────────────────────────────

/// 正在跑的那条会话（不变式上是 0 或 1 条）。
///
/// 计时页面和常驻通知都看它，谁也不自己记「现在有没有在计时」——
/// 那份记录在进程被杀掉之后就没了，而库里的那条会话还在。
final StreamProvider<TodoFocusSession?> runningSessionProvider =
    StreamProvider<TodoFocusSession?>(
      (Ref ref) => ref.watch(focusSessionRepositoryProvider).watchRunning(),
    );

/// 常驻通知同步。
///
/// 和提醒调度器一样是「创建即生效」，所以 `main()` 里必须读一次把它拉起来；
/// Widget 测试不读它，就不会碰到任何通知平台通道。
final Provider<FocusNotificationSync> focusNotificationSyncProvider =
    Provider<FocusNotificationSync>((Ref ref) {
      final FocusNotificationSync sync = FocusNotificationSync(
        sessions: ref.watch(focusSessionRepositoryProvider).watchRunning(),
        notifications: ref.watch(notificationServiceProvider),
      );
      sync.start();
      ref.onDispose(sync.dispose);
      return sync;
    });

/// 统计页的窗口数据：最近一年（含今天），在内存里算好。
///
/// 一次把一年读进来而不是一个月一个月查：一年最多几千条，一次查询比十几次
/// 小查询快，也不会出现「翻到上个月时数字先空一下」。
///
/// **`autoDispose` 是这里的关键**：统计页离开时监听者归零，这份快照就跟着
/// 丢掉，下次打开重新读一遍。没有它的话，刚结束一段专注再打开统计页，
/// 看到的还是应用启动那次算的数字——而且永远不会自己变。
final AutoDisposeFutureProvider<FocusStats> focusStatsProvider =
    FutureProvider.autoDispose<FocusStats>((Ref ref) async {
      final DateTime now = DateTime.now();
      final DateTime todayLocal = fromUtcMillis(dayOnlyMillis(now));
      final int to = dayOnlyMillis(todayLocal);
      final int from = dayOnlyMillis(
        DateTime(
          todayLocal.year,
          todayLocal.month,
          todayLocal.day - (kFocusStatsWindowDays - 1),
        ),
      );
      final List<FocusSlice> slices = await ref
          .watch(focusSessionRepositoryProvider)
          .slicesBetween(from: from, to: to, now: now);
      return FocusStats.from(slices: slices, from: from, to: to);
    });

/// 徽章的进度：由**全部**专注记录现推，不落表、不缓存解锁状态。
///
/// 与统计页的窗口不同，这里不截 365 天：「累计 100 小时」算的是一辈子的账，
/// 截窗口会让已经达成的徽章在某天忽然又锁上。
///
/// `autoDispose` 的理由同 [focusStatsProvider]：离开徽章页就丢掉，下次进来
/// 重算——刚做完一段专注再去看，进度必须已经是新的。
final AutoDisposeFutureProvider<AchievementBoard> achievementsProvider =
    FutureProvider.autoDispose<AchievementBoard>((Ref ref) async {
      final DateTime now = DateTime.now();
      final int today = dayOnlyMillis(now);
      // from 给 0：`logicalDate` 的闭区间其实是从 1970 年开始，
      // 不可能有记录落在它之前。
      final List<FocusSlice> slices = await ref
          .watch(focusSessionRepositoryProvider)
          .slicesBetween(from: 0, to: today, now: now);
      final AchievementFacts facts = AchievementFacts.from(
        slices: slices,
        today: today,
      );
      return AchievementBoard(
        facts: facts,
        progress: evaluateAchievements(facts),
      );
    });

// ───────────────────────────── 桌面小组件 ─────────────────────────────

/// 小组件的写入通道。
///
/// 桌面端会走到 no-op 分支，所以 Widget 测试不读它就不会碰到任何平台通道。
final Provider<HomeWidgetService> homeWidgetServiceProvider =
    Provider<HomeWidgetService>((Ref ref) => MethodChannelHomeWidgetService());

/// 桌面小组件同步。
///
/// 和提醒调度器一样是「创建即生效」，所以 `main()` 里要读一次把它拉起来。
///
/// 快照只覆盖最近七天（含今天），和统计页那一年的窗口不是一回事：小组件上
/// 只有一行格子。窗口的日期算术在 `home_widget_snapshot.dart` 里，查库和
/// 算快照用的是同一份。
final Provider<HomeWidgetSync> homeWidgetSyncProvider =
    Provider<HomeWidgetSync>((Ref ref) {
      final FocusSessionRepository sessions = ref.watch(
        focusSessionRepositoryProvider,
      );
      final HomeWidgetSync sync = HomeWidgetSync(
        sessions: sessions.watchRunning(),
        service: ref.watch(homeWidgetServiceProvider),
        build: () async {
          final DateTime now = DateTime.now();
          final int today = dayOnlyMillis(now);
          final List<FocusSlice> slices = await sessions.slicesBetween(
            from: homeWidgetWindowStart(today),
            to: today,
            now: now,
          );
          return HomeWidgetSnapshot.fromSlices(slices, today: today);
        },
      );
      sync.start();
      ref.onDispose(sync.dispose);
      return sync;
    });
