import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/constants/app_constants.dart';
import 'core/models/entities.dart';
import 'data/database/app_database.dart';
import 'data/repositories/settings_repository.dart';

/// 入口。
///
/// 顺序很重要，别随手调：
/// 1. `ensureInitialized()` —— 建表 / 补内置清单与设置行（幂等，见 [AppDatabase.ensureInitialized]）；
/// 2. 读一次偏好快照 —— 首屏的默认视图与主题要用它；
/// 3. 才 `runApp`。
///
/// 把第 2 步放在 `runApp` 之前，是为了让首帧就知道该用「今天」还是「全部」，
/// 不会先渲染一屏「全部」再跳成「今天」。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDatabase database = AppDatabase();
  final AppPreferences preferences;
  try {
    await database.ensureInitialized();
    preferences = await SettingsRepository(database).load();
  } on Object catch (error) {
    // 数据库打不开就没法假装还能用。明确报出来，比空白首屏好定位。
    // 这里是唯一允许吞掉异常并转向降级界面的地方——启动阶段的失败
    // 没有别的恢复手段，见 docs/ARCHITECTURE.md §10。
    runApp(BootstrapFailureApp(error: error));
    return;
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        // 复用已经打开的连接，避免第二次构造 AppDatabase。
        appDatabaseProvider.overrideWithValue(database),
        initialPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const NowTodoApp(),
    ),
  );
}

/// 启动失败时的兜底界面。
///
/// 存在的意义：让用户看到「发生了什么」，而不是对着一个转圈的首屏无限等待。
class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '本地数据库打不开',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text('$error'),
                  const SizedBox(height: 12),
                  const Text('任务数据全部保存在本机，不会上传。重启应用通常会重新尝试。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
