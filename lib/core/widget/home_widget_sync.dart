import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import 'home_widget_service.dart';
import 'home_widget_snapshot.dart';

/// 把最新快照推给桌面小组件。
///
/// 触发点只有两个：启动时推一次、专注会话变化时推一次。**不开定时器**——
/// 「今天专注了多久」只会因为会话变化而变，而小组件在应用不在时的重画由
/// 系统那边的刷新周期负责（画的还是上一次推过去的快照）。
///
/// 推送走串行队列，理由和 `FocusNotificationSync` 一样：一段专注结束时
/// 会连着来几个状态变更，交错着写会让最后落在桌面上的那份是旧的。
class HomeWidgetSync {
  HomeWidgetSync({
    required Stream<TodoFocusSession?> sessions,
    required HomeWidgetService service,
    required Future<HomeWidgetSnapshot> Function() build,
  }) : _sessions = sessions,
       _service = service,
       _build = build;

  final Stream<TodoFocusSession?> _sessions;
  final HomeWidgetService _service;
  final Future<HomeWidgetSnapshot> Function() _build;

  StreamSubscription<TodoFocusSession?>? _subscription;
  Future<void> _queue = Future<void>.value();

  /// 订阅会话流，并先推一次。可以重复调用，只生效一次。
  void start() {
    if (_subscription != null) return;
    _subscription = _sessions.listen(
      (_) => _enqueue(),
      onError: (Object error) => debugPrint('小组件同步失败：$error'),
    );
    // 不先推一次的话，用户装完应用、桌面上加了小组件，看到的会是空的——
    // 非要等下一次专注结束才有内容。
    _enqueue();
  }

  /// 当前排队中的推送全部跑完之后才完成。测试用它断言「已经收敛」。
  Future<void> get settled => _queue;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _enqueue() {
    _queue = _queue
        .then((_) async => _service.update(await _build()))
        .catchError((Object error) => debugPrint('小组件同步失败：$error'));
  }
}
