import 'package:drift/native.dart';
import 'package:now_todo/data/database/app_database.dart';

/// 造一个跑在内存里的数据库。
///
/// 用内存库而不是临时文件：测试之间天然隔离，不用清理，
/// 也不会因为上一次跑崩了留下半截数据影响下一次。
///
/// 原生库不用手工接管：`package:sqlite3` 在 Windows 上先找
/// `sqlite3.dll`，找不到会自动退回系统自带的 `winsqlite3.dll`；
/// 在 Linux（CI 的 ubuntu runner）上找 `libsqlite3.so.0`，镜像里自带。
/// 所以这里不需要 `open.overrideFor`。
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
