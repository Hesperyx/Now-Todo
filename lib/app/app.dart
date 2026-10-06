import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/models/entities.dart';
import '../core/models/enums.dart';
import '../core/theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

/// 应用外壳。
///
/// 只做三件事：把 `ThemeData` 接上去、把偏好里的主题模式转成 [ThemeMode]、
/// 把路由表交给 `MaterialApp.router`。没有业务逻辑。
class NowTodoApp extends ConsumerWidget {
  const NowTodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppPreferences> preferences = ref.watch(
      preferencesProvider,
    );
    final GoRouter router = ref.watch(appRouterProvider);

    // 偏好还没读出来时按「跟随系统」渲染。首屏闪一下浅色/深色，
    // 比先白屏等数据库快得多；`main()` 已经把首份快照读进
    // initialPreferencesProvider，真正等待的只有极短的第一次发射。
    final ThemeModeSetting setting =
        preferences.valueOrNull?.themeMode ?? ThemeModeSetting.system;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppTheme.resolve(setting),
      routerConfig: router,
    );
  }
}
