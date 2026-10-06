import 'package:drift/drift.dart';

import '../../core/models/entities.dart';
import '../../core/models/enums.dart';
import '../../core/utils/time.dart';
import '../database/app_database.dart';

/// 用户偏好读写。
///
/// 底层是**单行表**（`app_settings`），所以每个方法都先确保那一行存在。
/// 为什么不靠 `ensureInitialized()` 之后就不再管：用户可能拿到一个
/// 从别处复制来的、还没有设置行的数据库文件。少一行数据比崩溃好。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// 监听偏好变化。读不到时发射默认值，界面永远不会因为「没有设置行」空着。
  Stream<AppPreferences> watch() {
    return _db
        .select(_db.appSettings)
        .watchSingleOrNull()
        .map(
          (AppSetting? row) => row == null ? const AppPreferences() : _map(row),
        );
  }

  Future<AppPreferences> load() async {
    final AppSetting? row = await _db.select(_db.appSettings).getSingleOrNull();
    return row == null ? const AppPreferences() : _map(row);
  }

  /// 局部更新。只写传进来的字段。
  ///
  /// 参数多了以后，两处（新建那一行 / 更新已有那行）各写一遍 `Value` 包装
  /// 是错误温床：漏掉一个字段的表现是「设置点了没反应」，而且不报错。
  /// 所以先把补丁拼一次，再分别补上各自要补的列。
  Future<void> update({
    ThemeModeSetting? themeMode,
    DefaultView? defaultView,
    bool? notificationsEnabled,
    bool? strongReminders,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    bool? autoStartNext,
    FocusTimerMode? defaultTimerMode,
    bool? midnightMode,
    int? midnightEndHour,
  }) async {
    final int now = nowUtcMillis();
    final AppSettingsCompanion patch = AppSettingsCompanion(
      themeMode: _patch(themeMode),
      defaultView: _patch(defaultView),
      notificationsEnabled: _patch(notificationsEnabled),
      strongReminders: _patch(strongReminders),
      focusMinutes: _patch(focusMinutes),
      shortBreakMinutes: _patch(shortBreakMinutes),
      longBreakMinutes: _patch(longBreakMinutes),
      roundsBeforeLongBreak: _patch(roundsBeforeLongBreak),
      autoStartNext: _patch(autoStartNext),
      defaultTimerMode: _patch(defaultTimerMode),
      midnightMode: _patch(midnightMode),
      midnightEndHour: _patch(midnightEndHour),
    );

    final AppSetting? existing = await _db
        .select(_db.appSettings)
        .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.appSettings)
          .insert(
            patch.copyWith(initializedAt: Value(now), updatedAt: Value(now)),
          );
      return;
    }

    await (_db.update(_db.appSettings)
          ..where(($AppSettingsTable t) => t.id.equals(existing.id)))
        .write(patch.copyWith(updatedAt: Value(now)));
  }

  /// `null` 入参 = 不改这一列，而不是「置为 null」。
  ///
  /// 这里所有列都是非空列，所以这个区分不会丢信息；将来真加了可空设置列，
  /// 得换成一个显式哨兵，别指望这个函数。
  static Value<T> _patch<T>(T? input) =>
      input == null ? const Value.absent() : Value<T>(input);

  static AppPreferences _map(AppSetting row) => AppPreferences(
    themeMode: row.themeMode,
    defaultView: row.defaultView,
    notificationsEnabled: row.notificationsEnabled,
    strongReminders: row.strongReminders,
    focusMinutes: row.focusMinutes,
    shortBreakMinutes: row.shortBreakMinutes,
    longBreakMinutes: row.longBreakMinutes,
    roundsBeforeLongBreak: row.roundsBeforeLongBreak,
    autoStartNext: row.autoStartNext,
    defaultTimerMode: row.defaultTimerMode,
    midnightMode: row.midnightMode,
    midnightEndHour: row.midnightEndHour,
    initializedAt: row.initializedAt,
  );
}
