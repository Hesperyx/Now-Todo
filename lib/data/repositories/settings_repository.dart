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
  Future<void> update({
    ThemeModeSetting? themeMode,
    DefaultView? defaultView,
    bool? notificationsEnabled,
  }) async {
    final int now = nowUtcMillis();
    final AppSetting? existing = await _db
        .select(_db.appSettings)
        .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              themeMode: themeMode == null
                  ? const Value.absent()
                  : Value(themeMode),
              defaultView: defaultView == null
                  ? const Value.absent()
                  : Value(defaultView),
              notificationsEnabled: notificationsEnabled == null
                  ? const Value.absent()
                  : Value(notificationsEnabled),
              initializedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return;
    }

    await (_db.update(
      _db.appSettings,
    )..where(($AppSettingsTable t) => t.id.equals(existing.id))).write(
      AppSettingsCompanion(
        themeMode: themeMode == null ? const Value.absent() : Value(themeMode),
        defaultView: defaultView == null
            ? const Value.absent()
            : Value(defaultView),
        notificationsEnabled: notificationsEnabled == null
            ? const Value.absent()
            : Value(notificationsEnabled),
        updatedAt: Value(now),
      ),
    );
  }

  static AppPreferences _map(AppSetting row) => AppPreferences(
    themeMode: row.themeMode,
    defaultView: row.defaultView,
    notificationsEnabled: row.notificationsEnabled,
    initializedAt: row.initializedAt,
  );
}
