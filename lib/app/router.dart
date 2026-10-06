import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_page.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../features/task_editor/task_editor_page.dart';

/// 全部路由路径。
///
/// 集中成常量而不是在各处写字符串字面量：路径打错时是编译错误，
/// 而不是运行时跳到一个空白页。
abstract final class AppRoutes {
  static const String home = '/';

  /// 新建任务。注意这条必须声明在 `taskDetail` **之前**，
  /// 否则 `new` 会被当成一个任务 id 匹配掉。
  static const String taskNew = '/task/new';

  static const String taskDetailPattern = '/task/:id';

  /// 跳转到某条任务的编辑页。
  static String taskDetail(String id) => '/task/$id';

  static const String settings = '/settings';
  static const String about = '/about';
}

/// 路由表。
///
/// 用 `Provider` 而不是顶层 `final` 变量：全局单例的 router 在
/// Widget 测试之间会互为脏状态（上一次测试的栈还留着），
/// 放进 provider 就能随 container 一起销毁。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.taskNew,
        builder: (context, state) => const TaskEditorPage(),
      ),
      GoRoute(
        path: AppRoutes.taskDetailPattern,
        builder: (context, state) =>
            TaskEditorPage(taskId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
