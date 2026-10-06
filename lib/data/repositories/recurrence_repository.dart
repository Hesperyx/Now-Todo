import 'package:drift/drift.dart';

// 领域里的规则与 drift 生成的数据类同名（都叫 `RecurrenceRule`），加前缀是为了
// 让「这一处的 RecurrenceRule 是哪个」一眼可见：`core.` 开头的是领域对象。
import '../../core/recurrence/recurrence_rule.dart' as core;
import '../../core/utils/ids.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';

/// 把数据库里的一行重复规则解成领域对象。
///
/// 公开是因为 `TaskRepository` 也要用它：「完成后生成下一条」得先知道规则，
/// 而规则的解析（逗号分隔的数字、本地日期换算、锚点为 0 的兜底）只有一份。
core.RecurrenceRule decodeRule(RecurrenceRule row) {
  return core.RecurrenceRule(
    // `startsOn` 的默认值 0 只可能是「没写过」——表在 v1 就建好了，而 v4
    // 之前没有任何代码往里写过。真遇到这种行，用创建时间兜底比抛异常好：
    // 用户至少还能看到一条规则，而不是一个打不开的任务。
    startsOn: fromUtcMillis(row.startsOn == 0 ? row.createdAt : row.startsOn),
    frequency: row.frequency,
    interval: row.interval,
    byWeekday: _parseInts(row.byWeekday),
    byMonthDay: _parseInts(row.byMonthDay),
    endDate: row.endDate == null ? null : fromUtcMillis(row.endDate!),
    endCount: row.endCount,
  );
}

/// 重复规则的读写。
///
/// **规则与任务是两张表**：`tasks.recurrence_rule_id` 指过来，一个规则可以
/// 被同系列的每一条实例共用。删规则不会删实例（外键是 `ON DELETE SET NULL`），
/// 所以「结束重复」之后历史记录仍然在，只是不再属于一个系列。
class RecurrenceRepository {
  RecurrenceRepository(this._db);

  final AppDatabase _db;

  /// 某个任务身上的规则。任务不存在或没有规则时返回 `null`。
  Future<core.RecurrenceRule?> findForTask(String taskId) async {
    final String? ruleId = await _ruleIdOf(taskId);
    if (ruleId == null) return null;

    final RecurrenceRule? row = await (_db.select(
      _db.recurrenceRules,
    )..where((r) => r.id.equals(ruleId))).getSingleOrNull();
    return row == null ? null : decodeRule(row);
  }

  /// 监听某个任务的规则。规则行本身被改动（比如「此后全部」改了锚点）时
  /// 也会重新发射，所以这里 join 两张表，而不是只看任务那一行。
  Stream<core.RecurrenceRule?> watchForTask(String taskId) {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        _db.select(_db.tasks).join(<Join<HasResultSet, dynamic>>[
          leftOuterJoin(
            _db.recurrenceRules,
            _db.recurrenceRules.id.equalsExp(_db.tasks.recurrenceRuleId),
          ),
        ])..where(_db.tasks.id.equals(taskId));

    return query.watchSingleOrNull().map((TypedResult? row) {
      final RecurrenceRule? rule = row?.readTableOrNull(_db.recurrenceRules);
      return rule == null ? null : decodeRule(rule);
    });
  }

  /// 新建一条规则，返回新 id。
  ///
  /// 写入前把越界值收口：[core.RecurrenceRule.normalized] 保证「间隔至少 1、
  /// 星期在 1–7、号数在 1–31」，坏数字到这里为止，不让它进数据库。
  Future<String> create(core.RecurrenceRule rule) async {
    final String id = newId();
    final core.RecurrenceRule clean = rule.normalized();
    await _db
        .into(_db.recurrenceRules)
        .insert(
          RecurrenceRulesCompanion.insert(
            id: id,
            frequency: clean.frequency,
            interval: Value(clean.interval),
            startsOn: Value(clean.startsOn.utcMillis),
            byWeekday: Value(_joinInts(clean.byWeekday)),
            byMonthDay: Value(_joinInts(clean.byMonthDay)),
            endDate: Value(
              clean.endDate == null ? null : dayOnlyMillis(clean.endDate!),
            ),
            endCount: Value(clean.endCount),
            createdAt: nowUtcMillis(),
          ),
        );
    return id;
  }

  Future<void> update(String id, core.RecurrenceRule rule) async {
    final core.RecurrenceRule clean = rule.normalized();
    await (_db.update(
      _db.recurrenceRules,
    )..where((r) => r.id.equals(id))).write(
      RecurrenceRulesCompanion(
        frequency: Value(clean.frequency),
        interval: Value(clean.interval),
        // 和 create 保持一致：锚点存完整时刻。带时刻的重复任务（每天 09:30）
        // 靠它保住那个时刻，日期化留给生成下一条时按 `dueDateHasTime` 决定。
        startsOn: Value(clean.startsOn.utcMillis),
        byWeekday: Value(_joinInts(clean.byWeekday)),
        byMonthDay: Value(_joinInts(clean.byMonthDay)),
        endDate: Value(
          clean.endDate == null ? null : dayOnlyMillis(clean.endDate!),
        ),
        endCount: Value(clean.endCount),
      ),
    );
  }

  /// 删掉规则。历史实例不会跟着消失——`tasks.recurrence_rule_id` 是
  /// `ON DELETE SET NULL`，它们只是不再属于一个系列。
  Future<void> delete(String id) async {
    await (_db.delete(_db.recurrenceRules)..where((r) => r.id.equals(id))).go();
  }

  /// 把某个任务的重复设置调成 [draft]，返回任务该记下的规则 id。
  ///
  /// - [draft] 为 `null` = 不再重复：旧规则删掉（历史实例留下）。
  /// - [keepSeriesAnchor] 为 `true` = 用户选了「仅此一次」：规则里别的字段照写，
  ///   但**锚点保持原样**。这一步是「仅此一次」与「此后全部」唯一的区别——
  ///   锚点不动，被改过的这条实例就会被 `occurrenceOnOrBefore` 吸回原节奏，
  ///   系列还是原来的系列。
  Future<String?> apply({
    required String taskId,
    required core.RecurrenceRule? draft,
    bool keepSeriesAnchor = false,
  }) async {
    final String? existingId = await _ruleIdOf(taskId);

    if (draft == null) {
      if (existingId != null) await delete(existingId);
      return null;
    }
    if (existingId == null) return create(draft);

    if (keepSeriesAnchor) {
      final RecurrenceRule? row = await (_db.select(
        _db.recurrenceRules,
      )..where((r) => r.id.equals(existingId))).getSingleOrNull();
      if (row != null) {
        await update(
          existingId,
          draft.copyWith(startsOn: decodeRule(row).startsOn),
        );
        return existingId;
      }
    }
    await update(existingId, draft);
    return existingId;
  }

  /// 任务身上记的规则 id。
  Future<String?> _ruleIdOf(String taskId) async {
    final Task? task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    return task?.recurrenceRuleId;
  }
}

/// `"1,3,5"` → `{1,3,5}`。解析不出来的片段直接丢掉——坏数据不该让整条规则失效。
Set<int> _parseInts(String? text) {
  if (text == null) return const <int>{};
  final Set<int> values = <int>{};
  for (final String part in text.split(',')) {
    final int? value = int.tryParse(part.trim());
    if (value != null) values.add(value);
  }
  return values;
}

/// 反过来。空集合存 `NULL` 而不是空串：空串与「没设置」在 SQL 里应该是一回事。
String? _joinInts(Set<int> values) {
  if (values.isEmpty) return null;
  final List<int> sorted = values.toList()..sort();
  return sorted.join(',');
}
