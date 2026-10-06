import 'package:drift/drift.dart';

import '../../core/focus/focus_stats.dart';
import '../../core/focus/focus_timer.dart';
import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';

/// 专注会话读写。
///
/// 时间算术**一律转发给 [FocusTimerState]**：暂停时要冻住、恢复时要补上
/// 暂停时长、结束时要判断有没有走满——这几件事在计时内核里各有一条用例，
/// 仓储里再写一遍毫秒加减，就等于把同一套规则实现两次。
class FocusSessionRepository {
  FocusSessionRepository(this._db);

  final AppDatabase _db;

  // ───────────────────────────── 读 ─────────────────────────────

  /// 监听某个逻辑日的全部会话，按开始时刻升序。
  Stream<List<TodoFocusSession>> watchDay(int logicalDate) {
    return (_db.select(_db.focusSessions)
          ..where((t) => t.logicalDate.equals(logicalDate))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch()
        .map(_mapAll);
  }

  /// 监听逻辑日区间（闭区间）内的全部会话。
  Stream<List<TodoFocusSession>> watchBetween({
    required int from,
    required int to,
  }) {
    return (_db.select(_db.focusSessions)
          ..where((t) => t.logicalDate.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch()
        .map(_mapAll);
  }

  /// 监听全部会话。统计页用，数据量大起来之后要换成按区间取。
  Stream<List<TodoFocusSession>> watchAll() {
    return (_db.select(
      _db.focusSessions,
    )..orderBy([(t) => OrderingTerm.asc(t.startedAt)])).watch().map(_mapAll);
  }

  /// 一次性的区间读（闭区间），给导出和测试用。
  Future<List<TodoFocusSession>> listBetween({
    required int from,
    required int to,
  }) async {
    final List<FocusSession> rows =
        await (_db.select(_db.focusSessions)
              ..where((t) => t.logicalDate.isBetweenValues(from, to))
              ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  /// 直接喂给 `lib/core/focus/focus_stats.dart` 的聚合切片。
  ///
  /// [now] 用来给**还没结束**的那条补上实时时长：它落库的 `actual_seconds`
  /// 只有在暂停或结束的那一刻才会被写上，中间是 0。已经结束的走库里存的
  /// 实际时长，不再二次计算——统计口径必须和当时记下来的那笔一致。
  Future<List<FocusSlice>> slicesBetween({
    required int from,
    required int to,
    required DateTime now,
  }) async {
    final List<TodoFocusSession> rows = await listBetween(from: from, to: to);
    return rows
        .map(
          (TodoFocusSession s) => FocusSlice(
            logicalDate: s.logicalDate,
            startedAt: s.startedAt,
            seconds: s.isRunning ? s.elapsedSeconds(now) : s.actualSeconds,
          ),
        )
        .toList(growable: false);
  }

  /// 还没结束的会话。正常最多一条，用列表是为了在不变式被破坏时能看见，
  /// 而不是让 `getSingleOrNull()` 抛一个看不懂的异常。
  Future<List<TodoFocusSession>> unfinished() async {
    final List<FocusSession> rows =
        await (_db.select(_db.focusSessions)
              ..where((t) => t.endedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  /// 正在跑的那条。App 重启后靠它恢复计时。
  Future<TodoFocusSession?> running() async {
    final FocusSession? row =
        await (_db.select(_db.focusSessions)
              ..where((t) => t.endedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// 按 id 读一条。读不到返回 `null`。
  ///
  /// 收尾之后要拿**更新过的**那一份（`actualSeconds` 和 `completed` 都是
  /// 结束时才写上的），而调用方手里那个对象是开始那一刻的快照。用它来填
  /// 「这一段记下了 / 实际 00:00」这种界面，就是在对着用户说假话。
  Future<TodoFocusSession?> findById(String id) async {
    final FocusSession? row = await (_db.select(
      _db.focusSessions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Stream<TodoFocusSession?> watchRunning() {
    return (_db.select(_db.focusSessions)
          ..where((t) => t.endedAt.isNull())
          ..limit(1))
        .watchSingleOrNull()
        .map((FocusSession? row) => row == null ? null : _map(row));
  }

  // ───────────────────────────── 写 ─────────────────────────────

  /// 开始一次会话，返回新 id。
  ///
  /// [logicalDate] 由调用方用 `logicalDateFor(...)` 在**开始的那一刻**算好。
  /// 归属日属于「写一次就冻结」的事实：午夜模式下 23:50 开始、次日 00:20
  /// 结束的这段，整段都该算在昨晚头上，不能在收尾时重新算。
  ///
  /// 同一个事务里会先把还没结束的会话收掉，保证「最多只有一条
  /// `endedAt IS NULL`」这条不变式。这里**不报错拒绝**：调用方可能是崩溃
  /// 恢复之后的重开，那条僵尸会话在语义上已经被新的取代了。
  Future<String> start({
    required DateTime at,
    required int logicalDate,
    String? taskId,
    FocusSessionKind kind = FocusSessionKind.focus,
    FocusTimerMode mode = FocusTimerMode.countDown,
    Duration? plan,
  }) async {
    assert(mode == FocusTimerMode.countDown || plan == null, '正计时不该给计划时长');
    final int? plannedSeconds = mode == FocusTimerMode.countDown
        ? (plan ?? FocusTimerState.defaultPlan).inSeconds
        : null;
    final String id = newId();

    await _db.transaction(() async {
      await _closeRunning(before: at);
      await _db
          .into(_db.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              id: id,
              taskId: Value<String?>(taskId),
              startedAt: at.utcMillis,
              plannedSeconds: Value<int?>(plannedSeconds),
              kind: Value<FocusSessionKind>(kind),
              timerMode: Value<FocusTimerMode>(mode),
              logicalDate: logicalDate,
            ),
          );
    });
    return id;
  }

  Future<void> pause(String id, DateTime at) async {
    final TodoFocusSession session = await _require(id);
    await _writePause(id, session.toTimerState().pause(at));
  }

  Future<void> resume(String id, DateTime at) async {
    final TodoFocusSession session = await _require(id);
    await _writePause(id, session.toTimerState().resume(at));
  }

  /// 结束一次会话。
  ///
  /// `completed` 由计时内核判断（走满了才算），正计时永远是 `false`——
  /// 它没有「走满」这回事。暂停中结束的话，时长停在暂停那一刻。
  Future<void> finish(String id, {required DateTime at}) async {
    final TodoFocusSession session = await _require(id);
    final FocusTimerState state = session.toTimerState();
    await (_db.update(_db.focusSessions)..where((t) => t.id.equals(id))).write(
      FocusSessionsCompanion(
        endedAt: Value<int>(at.utcMillis),
        actualSeconds: Value<int>(state.elapsed(at).inSeconds),
        pausedMillis: Value<int>(state.pausedMillis.inMilliseconds),
        pausedAt: const Value<int?>(null),
        completed: Value<bool>(state.isFinished(at)),
      ),
    );
  }

  /// 删掉一条会话。
  ///
  /// 用在两个地方：误触之后把还没跑多久的会话撤掉，以及清理不该记的历史。
  /// 想保留就调 [finish]，它留下的是「我记得有这么一段」。
  Future<void> cancel(String id) async {
    await (_db.delete(_db.focusSessions)..where((t) => t.id.equals(id))).go();
  }

  /// 换掉归属任务。传 `null` 表示改成自由专注。
  Future<void> assignTask(String id, String? taskId) async {
    await (_db.update(_db.focusSessions)..where((t) => t.id.equals(id))).write(
      FocusSessionsCompanion(taskId: Value<String?>(taskId)),
    );
  }

  /// 补写备注。传 `null` 表示清空。
  Future<void> setNote(String id, String? note) async {
    await (_db.update(_db.focusSessions)..where((t) => t.id.equals(id))).write(
      FocusSessionsCompanion(note: Value<String?>(note)),
    );
  }

  // ────────────────────────── 内部 ──────────────────────────

  /// 收掉还没结束的会话：停在 [before]，并按内核补算时长。
  ///
  /// 补算而**不是**直接写 0：被取代的那一段是真实发生过的时间，凭空抹掉
  /// 比留着一段可疑记录更糟。`completed` 也照实判，所以一条早就走满、
  /// 只是没人点结束的会话仍然算完成。
  Future<void> _closeRunning({required DateTime before}) async {
    final List<FocusSession> rows = await (_db.select(
      _db.focusSessions,
    )..where((t) => t.endedAt.isNull())).get();
    for (final FocusSession row in rows) {
      final FocusTimerState state = _map(row).toTimerState();
      await (_db.update(
        _db.focusSessions,
      )..where((t) => t.id.equals(row.id))).write(
        FocusSessionsCompanion(
          endedAt: Value<int>(before.utcMillis),
          actualSeconds: Value<int>(state.elapsed(before).inSeconds),
          pausedMillis: Value<int>(state.pausedMillis.inMilliseconds),
          pausedAt: const Value<int?>(null),
          completed: Value<bool>(state.isFinished(before)),
        ),
      );
    }
  }

  Future<void> _writePause(String id, FocusTimerState state) async {
    await (_db.update(_db.focusSessions)..where((t) => t.id.equals(id))).write(
      FocusSessionsCompanion(
        pausedMillis: Value<int>(state.pausedMillis.inMilliseconds),
        pausedAt: Value<int?>(state.pausedAt?.utcMillis),
      ),
    );
  }

  Future<TodoFocusSession> _require(String id) async {
    final FocusSession? row = await (_db.select(
      _db.focusSessions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('找不到这条专注会话：$id');
    }
    return _map(row);
  }

  static List<TodoFocusSession> _mapAll(List<FocusSession> rows) =>
      rows.map(_map).toList(growable: false);

  static TodoFocusSession _map(FocusSession row) => TodoFocusSession(
    id: row.id,
    taskId: row.taskId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    pausedMillis: row.pausedMillis,
    pausedAt: row.pausedAt,
    plannedSeconds: row.plannedSeconds,
    actualSeconds: row.actualSeconds,
    kind: row.kind,
    timerMode: row.timerMode,
    logicalDate: row.logicalDate,
    completed: row.completed,
    note: row.note,
  );
}
