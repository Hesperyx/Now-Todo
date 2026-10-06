import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:now_todo/core/models/entities.dart';
import 'package:now_todo/core/models/enums.dart';
import 'package:now_todo/data/database/app_database.dart';
import 'package:now_todo/data/repositories/settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('一行都没有的时候读到默认值，而不是报错', () async {
    final AppPreferences prefs = await repo.load();

    expect(prefs.themeMode, ThemeModeSetting.system);
    expect(prefs.defaultView, DefaultView.today);
    expect(prefs.notificationsEnabled, isTrue);
    expect(prefs.initializedAt, isNull);
  });

  test('没有行时 watch 也发射默认值', () async {
    final AppPreferences prefs = await repo.watch().first;

    expect(prefs.themeMode, ThemeModeSetting.system);
    expect(prefs.defaultView, DefaultView.today);
  });

  test('往空表写偏好会先把那一行建出来', () async {
    await repo.update(themeMode: ThemeModeSetting.dark);

    final AppPreferences prefs = await repo.load();
    expect(prefs.themeMode, ThemeModeSetting.dark);
    expect(prefs.initializedAt, isNotNull);
  });

  test('update 只动传进来的字段', () async {
    await repo.update(
      themeMode: ThemeModeSetting.dark,
      defaultView: DefaultView.all,
    );
    await repo.update(notificationsEnabled: false);

    final AppPreferences prefs = await repo.load();
    expect(prefs.themeMode, ThemeModeSetting.dark);
    expect(prefs.defaultView, DefaultView.all);
    expect(prefs.notificationsEnabled, isFalse);
  });

  test('ensureInitialized 之后再改设置，没碰的字段保持原样', () async {
    await db.ensureInitialized();

    await repo.update(defaultView: DefaultView.completed);

    final AppPreferences prefs = await repo.load();
    expect(prefs.defaultView, DefaultView.completed);
    expect(prefs.themeMode, ThemeModeSetting.system);
    expect(prefs.notificationsEnabled, isTrue);
  });

  test('watch 会跟着 update 推新值', () async {
    final List<AppPreferences> seen = <AppPreferences>[];
    final StreamSubscription<AppPreferences> subscription = repo.watch().listen(
      seen.add,
    );
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    expect(seen.last.themeMode, ThemeModeSetting.system);

    await repo.update(themeMode: ThemeModeSetting.light);
    await pumpEventQueue();
    expect(seen.last.themeMode, ThemeModeSetting.light);
  });
}
