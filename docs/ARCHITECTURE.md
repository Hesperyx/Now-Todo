# 架构设计

本文档说明 Now Todo 的技术选型、分层结构与关键设计决策。**选型理由和被否决的备选方案一并记录**，避免后来者重复论证。

配套文档：[产品需求文档](PRD.md) · [里程碑](MILESTONES.md) · [贡献指南](../CONTRIBUTING.md)

---

## 1. 设计原则

按优先级排序。冲突时上位原则覆盖下位。

1. **离线优先**：核心功能（增删改查、提醒、搜索）不依赖网络。任何时候断网，应用必须完全可用。
2. **数据是用户的**：本地存储、公开的导出格式、明确的迁移路径。不设任何数据枷锁。
3. **隐私默认安全**：不采集任务内容，不默认开启任何上报，不要求账号。
4. **可测试**：业务逻辑（重复规则、提醒计算、导入校验）必须能脱离 UI 与设备测试。
5. **简单优先**：不引入当前范围用不到的抽象。首版不做的功能不预留半成品接口。

---

## 2. 技术选型

| 领域 | 选型 | 版本 | 理由 / 被否决的备选 |
| --- | --- | --- | --- |
| 框架 | Flutter stable | 3.35.5 | PRD 指定。双端一致 UI，单代码库。 |
| 语言 | Dart | 3.9.2 | 随 Flutter 附带。**这是当前的项目 SDK 上限**，见 §4。 |
| 状态管理 | `flutter_riverpod` | 2.6.1（锁定） | 编译期安全、无 `BuildContext` 依赖、测试时易替换。备选 Bloc 样板代码更多，Provider 缺乏编译期保障。 |
| 路由 | `go_router` | 17.2.3 | 声明式路由，支持深链接（未来的小组件跳转要用），与 Riverpod 无耦合。 |
| 数据库 | SQLite + Drift | drift 2.31.0 | PRD 建议方案。关系型查询（按标签/清单/日期交叉筛选）是核心需求；Drift 提供类型安全查询 + 可测试的迁移机制。备选 Hive 无关系查询能力，Isar 迁移与调试工具较弱。 |
| SQLite 运行时 | `sqlite3_flutter_libs` | 0.5.42 | 在 Android 与桌面提供一致的新版 SQLite，避免依赖系统版本。 |
| 数据库初始化 | `drift_flutter` | 0.2.8 | 封装各平台数据库文件路径，省掉手写 platform 分支。 |
| 本地提醒 | `flutter_local_notifications` | 20.1.0 | 成熟、支持 Android 定时通知与重复规则（通知渠道、精确闹钟、`SCHEDULE_EXACT_ALARM` 降级路径见 §7）。 |
| 时区 | `timezone` + `flutter_timezone` | 0.10.1 / 5.1.1 | 定时通知必须用带时区的绝对时间，否则跨时区/夏令时会偏移。 |
| 文件收发 | `file_picker` · `share_plus` · `path_provider` | 11.0.3 / 12.0.2 / 2.1.5 | 导入导出与分享备份文件。 |
| 日期格式化 | `intl` | 0.20.3 | 日期显示与本地化基础。 |
| ID 生成 | `uuid` | 4.6.0 | 客户端生成主键，便于将来合并与导入去重。 |
| 版本信息 | `package_info_plus` | 9.0.1 | 关于页展示版本号。 |
| 外部链接 | `url_launcher` | 6.3.2 | 捐赠入口、开源仓库链接。 |
| 测试替身 | `mocktail` | 1.0.5（dev） | 无需代码生成的 mock。 |
| 代码生成 | `build_runner` + `drift_dev` | 2.15.1 / 2.31.0（dev） | Drift 的生成器。 |

**不使用 Web 平台**：Drift 在 Web 上需要 WASM 版 SQLite，额外引入二进制加载与持久化策略，而首版目标是移动端。Windows 桌面仅作为开发期快速预览目标，不进入发布范围。

---

## 3. 分层结构

```
┌─────────────────────────────────────────────────────┐
│  features/          功能模块（UI + 状态）            │
│  tasks · lists · tags · search · settings           │
└───────────────────────┬─────────────────────────────┘
                        │ 只依赖 repository 接口
┌───────────────────────▼─────────────────────────────┐
│  data/repositories/  仓储层：领域模型 ↔ 数据源       │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│  data/database/      Drift 表定义 · DAO · 迁移       │
│  data/models/        领域模型 · 枚举 · 序列化        │
└─────────────────────────────────────────────────────┘
        core/    utils · extensions · constants · errors
```

**硬性依赖规则**：

- `features/` 可以 import `data/repositories`、`data/models`、`core/`。
- `features/` **不得** import `data/database/*.g.dart` 或任何 Drift 生成类型。
- `data/` **不得** import `features/`。
- `core/` **不得** import `data/` 或 `features/`。

理由：UI 与数据库解耦后，换存储实现、写 Widget 测试（注入假仓储）、做数据迁移验证都不需要动 UI 代码。

### 目录职责

| 路径 | 放什么 | 不放什么 |
| --- | --- | --- |
| `lib/app/` | `MaterialApp` 外壳、主题、`go_router` 路由表、根 Provider 作用域 | 业务逻辑 |
| `lib/core/` | 通用扩展、日期与字符串工具、常量、错误类型 | 任何依赖数据库的东西 |
| `lib/data/database/` | Drift 表、`AppDatabase`、DAO、迁移 | 业务规则 |
| `lib/data/models/` | 领域模型、枚举、JSON 序列化 | Flutter Widget |
| `lib/data/repositories/` | 仓储接口与实现，聚合多个 DAO | UI 状态 |
| `lib/features/<name>/` | 该功能的页面、Widget、Provider | 其它功能的内部实现 |

---

## 4. 依赖版本锁定与已知约束

> 这一节记录一个**实测确认的依赖死锁**。在升级 Flutter 之前，请先读完本节。

### 现象

在 Flutter 3.35.5 / Dart 3.9.2 上同时引入 `flutter_riverpod` 3.x 与 `drift_dev`，`pub` 报错：

```
Because now_todo depends on both flutter_test from sdk and drift_dev any,
version solving failed.
...
drift_dev >=2.31.0 <2.32.0 depends on analyzer >=8.1.0 <11.0.0
  and now_todo depends on flutter_riverpod ^3.3.2,
  drift_dev >=2.31.0 <2.32.0 is incompatible with flutter_test from sdk.
```

### 因果链（实测）

1. `flutter_riverpod` 3.x → `riverpod` 3.x → **运行时**依赖 `test ^1.0.0`。
   注意这是常规依赖而非 dev 依赖，`test` 因此被拉进主依赖图。
2. Flutter 3.35.5 内置的 `flutter_test` 钉死 `matcher 0.12.17` 与 `test_api 0.7.6`，
   把 `test` 压到 `1.26.2`。
3. `test >= 1.31.1` 要求 Dart SDK `>= 3.10.0`，本机为 **3.9.2**。
4. `drift_dev` 需要 `analyzer >= 8.1.0`；而上述约束组合下 `analyzer` 只能落在 `< 8.0.0`。

四者无交集。

### 同源受影响的包（一并排除）

| 包 | 被排除的原因 |
| --- | --- |
| `riverpod_lint` + `custom_lint` | `riverpod_lint >= 3.1.1` 要求 SDK `>= 3.10.0`；更早的版本要求 `analyzer ^6.9.0`，该区间依赖已被移除的 `macros`/`_macros`（Dart SDK 中已不存在）。 |
| `drift_dev >= 2.33.0` | 要求 SDK `>= 3.10.0`。 |
| `drift >= 2.32.0` | 要求 `sqlite3 ^3.1.5`，牵动更大的版本面，无必要。 |
| `riverpod_annotation` / `riverpod_generator` | 与 `riverpod_lint` 同一版本族，且代码生成会扩大 build_runner 的接触面。 |
| `share_plus` 13.x 等 | 仅因 SDK 上限落后一个大版本，功能不受影响。 |

### 采用的方案

显式锁定两个精确版本，其余用插入符约束：

```yaml
dependencies:
  flutter_riverpod: 2.6.1      # 精确锁定，理由见上
  drift: ^2.31.0
  drift_flutter: ^0.2.8

dev_dependencies:
  drift_dev: 2.31.0            # 精确锁定，理由见上
```

**实测结果**：`flutter pub get` 成功，实际解析为
`flutter_riverpod 2.6.1` · `riverpod 2.6.1` · `drift 2.31.0` · `drift_dev 2.31.0` ·
`drift_flutter 0.2.8` · `sqlite3 2.9.4` · `analyzer 10.0.1` · `build_runner 2.15.1`。

对功能的影响：**无**。Riverpod 2.6.1 是 2.x 的稳定收尾版本，本项目用到的
`Provider` / `NotifierProvider` / `AsyncNotifierProvider` / `Ref` 能力齐备。
Riverpod 3 主要带来离线持久化实验特性与 mutations，均不在 PRD 范围内。

**代价**：不能用 `riverpod_lint` 的代码生成向 lint。作为补偿，项目禁止 Riverpod 代码生成，
一律手写 provider，并在评审中人工把关 `ref.watch` / `ref.read` 的用法。

### 解除锁定的条件

当开发工具链升级到 **Dart SDK ≥ 3.11**（即 Flutter 升级到对应 stable）后，可以一次性解锁：

- `flutter_riverpod` → 3.4.x，`riverpod_lint` + `custom_lint` 重新可用
- `drift` / `drift_dev` → 2.35.x，`sqlite3` → 3.x
- `share_plus` → 13.x

升级时请按以下顺序验证，任一步失败即回退：

1. `flutter pub upgrade --major-versions`
2. `dart run build_runner build`
3. `flutter analyze && flutter test`
4. 手工回归：本地提醒在真机上仍按预期时区触发

**注意**：Flutter 是本机全局工具链，升级会影响同机其它项目。升级前请单独评估。

---

## 5. 数据模型

### 5.1 表设计

对应 PRD 的「数据模型建议」。主键统一使用 `TEXT` 类型的 UUID（客户端生成，便于导入合并）。

| 表 | 字段 | 说明 |
| --- | --- | --- |
| `tasks` | `id` `title` `note` `due_date` `due_date_has_time` `priority` `status` `list_id` `recurrence_rule_id` `created_at` `updated_at` `completed_at` `estimated_pomodoros` | `priority`: 0=无 1=低 2=中 3=高；`status`: 0=未完成 1=已完成；`due_date` 存 UTC 毫秒时间戳，可为空；`due_date_has_time` 区分「某天」与「某时刻」；`estimated_pomodoros` 可空——「没估过」与「估了 0 个」是两件事 |
| `task_lists` | `id` `name` `color` `is_built_in` `sort_order` `created_at` `updated_at` | 清单（PRD 中的 Checklist/List）；内置收件箱靠 `is_built_in` 标记，不可删 |
| `tags` | `id` `name` `color` `created_at` | 标签 |
| `task_tags` | `task_id` `tag_id` | 多对多关联表，复合主键 |
| `subtasks` | `id` `task_id` `title` `is_done` `sort_order` `created_at` | 子任务，父任务删除时级联删除 |
| `reminders` | `id` `task_id` `remind_at` `repeat_type` `enabled` `created_at` | 本地提醒；`repeat_type`: 0=仅一次 1=每天 2=每周 3=每月 |
| `recurrence_rules` | `id` `frequency` `interval` `starts_on` `by_weekday` `by_month_day` `end_date` `end_count` `created_at` | 重复规则；`frequency`: 0=每天 1=每周 2=每月 3=每年；`by_weekday` 存逗号分隔的 1–7；`starts_on` 是系列的锚点（完整时刻，本地时间的 UTC 毫秒），`end_count` 是「最多生成几条（含第 1 条）」，都可空/为 0 表示没写过——见 §5.3 |
| `focus_sessions` | `id` `task_id` `started_at` `ended_at` `paused_millis` `paused_at` `planned_seconds` `actual_seconds` `kind` `timer_mode` `logical_date` `completed` `note` | 专注 / 休息会话；`task_id` 用 `ON DELETE SET NULL`（删任务不抹掉已专注的历史）；`ended_at` 可空 = 进行中；`kind`: 0=专注 1=短休 2=长休；`timer_mode`: 0=正计时 1=倒计时；`logical_date` 是归属日（本地零点毫秒），写入时冻结 |
| `app_settings` | 单行、强类型列（主题、默认视图、提醒开关、强提醒、专注时长、午夜模式…） | 不用键值表：键值表要自己拼类型转换，且漏一个键只能在运行时报错 |

### 5.2 关键设计决策

**时间一律存 UTC 毫秒时间戳，不存本地时间字符串。**
跨时区、跨夏令时是提醒类应用最容易出 Bug 的地方。展示时再转本地时区（`intl`），
调度通知时用 `timezone` 转换。存储层永不出现「本地时间」。

**`updated_at` 每次写入必须刷新。**
未来若做同步或冲突合并，这是唯一可用的版本依据。

**删除策略**：首版采用硬删除。软删除（`deleted_at`）只在引入同步时才需要，
提前引入会让所有查询都要带 `WHERE deleted_at IS NULL`，属于为不存在的需求付成本。

**索引**：`tasks(status)`、`tasks(due_date)`、`tasks(list_id)`、`tasks(recurrence_rule_id)`、
`subtasks(task_id)`、`subtasks(task_id, sort_order)`、`reminders(task_id)`、`reminders(remind_at)`、
`task_lists(sort_order)`、`tags(name)`（唯一）、`task_tags(tag_id)`、
`focus_sessions(logical_date)`、`focus_sessions(task_id)`、`focus_sessions(started_at)`。
首页「今日」视图是最高频查询，`due_date` 索引必须有；统计与徽章只按 `logical_date` 扫，
所以那一列也必须有。

**级联**：`tasks` 删除 → 级联清理 `subtasks`、`reminders`、`task_tags`；
`focus_sessions.task_id` 用 `ON DELETE SET NULL` —— 任务没了，但「我在这件事上花了
两小时」是既成事实，不该跟着消失。用外键约束，不靠应用层记得手动删。
`tasks.recurrence_rule_id` 同样是 `ON DELETE SET NULL`：删除规则是「结束重复」，
历史实例（也就是用户实际做过的事）必须留下。

### 5.3 重复任务

**完成一条之后的动作是「生成下一条实例」，不是「推进这一条的截止日期」。**
实例就是一条任务行，推进日期等于把「上个月我确实做过这件事」这段历史抹掉，
而「结束重复不会删除历史已完成实例」是硬性验收。

**`recurrence_rules.startsOn` 是系列的锚点**，整个系列的日期都由它算起：

```
startsOn ──+1 次──> 第 2 条实例 ──+1 次──> 第 3 条实例
```

**永远从锚点加整数倍，不要从上一次结果再加一次。** 后者会让「31 日被夹到 28 日」的
偏差累积：1/31 → 2/28 → 3/28（错），正确是 1/31 → 2/28 → **3/31**。日期算术只写一遍，
在 `lib/core/recurrence/recurrence.dart`（计算）与 `lib/core/utils/time.dart`
的 `addMonthsClamped` / `addDaysKeepingTime`（工具）里，界面不自己算日期。

**「仅此一次」与「此后全部」的唯一区别是锚点动不动。**

- 仅此一次：只写这一条任务的 `due_date`，规则原样不动。下次生成时
  `occurrenceOnOrBefore(rule, 被挪过的日期)` 会把这个实例吸回原本的节奏上。
- 此后全部：把规则的 `startsOn` 一起挪到新日期，之后生成的实例跟着走。

**次数（`endCount`）只在 `nextAfterCompletion` 里判。** 它是「这个系列现在有几条任务」
的函数，`occurrenceAfter` 拿不到这个数，所以它只管日期上限。判两处就有两个权威。

**日期化的实例去对齐节奏时取当天 23:59:59.999**，带时刻的实例取它自己。取 00:00 会让
「锚点带时刻、实例只到日」的组合每次完成都生出同一天的下一条。

**生成与标记完成在同一个事务里**，返回新任务的 id 让界面提示「下一条：YYYY-MM-DD」。
重复勾选一条已完成的任务不会生成第二条。

**结束重复 = 删掉规则行**，历史实例都还在，只是不再知道彼此属于一个系列。
`endCount` 的计数口径是「现在有几条」，所以删掉一条历史会让系列多跑一次——
刻意的取舍，换来的是不必再为「系列」单独开一张表。

---

## 6. 数据库迁移

数据是用户资产，迁移是最高风险操作。

- **每次改表结构必须同时**：提升 `schemaVersion` → 写 `MigrationStrategy.onUpgrade` → 重新导出快照 → 补迁移测试。
- **禁止**在 `onUpgrade` 里 `deleteTable` / 重建库 / 静默丢列。
- **禁止**在没有测试的情况下发布带 `schemaVersion` 变更的版本。
- 无法自动迁移的破坏性变更必须：先在应用内提示用户导出备份，再提供显式的迁移入口。

### 6.1 加一次版本的五步

以「给 `app_settings` 加一列 `strongReminders`」为例（v1 → v2 就是这么做的）：

1. 改表定义（`lib/data/database/tables/*.dart`）。新列一律给 `withDefault`，
   老行靠列默认值补齐，**不需要写回填语句**。
2. 提升 `lib/data/database/app_database.dart` 的 `schemaVersion`，并在 `onUpgrade` 里加分支：
   ```dart
   for (var version = from; version < to; version++) {
     switch (version) {
       case 1: await m.addColumn(appSettings, appSettings.strongReminders);
     }
   }
   ```
3. `dart run build_runner build` —— 重新生成 Drift 代码。
4. `dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/`
   —— 导出新版本的结构快照（`drift_schema_vN.json`），它会入库。
5. `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/`
   —— 重新生成各历史版本的建表代码，然后在 `test/data/migration_test.dart` 补一条用例。

本机 `D:\develop\flutter\bin\` 下没有 `dart.exe`，把上面命令里的 `dart`
换成 `D:\develop\flutter\bin\cache\dart-sdk\bin\dart.exe`。

#### 两个已经踩过的坑

**一、新建表必须显式建索引。** `m.createTable(focusSessions)` **不会**顺手建
`@TableIndex` 声明的索引——只有 `m.createAll()` 会，因为它是按 `allSchemaEntities`
逐项建的（表走 `createTable`，索引走 `createIndex`）。所以 v2 → v3 里是：

```dart
case 2:
  await m.createTable(focusSessions);
  await m.createIndex(focusSessionsLogicalDate);
  await m.createIndex(focusSessionsTaskId);
  await m.createIndex(focusSessionsStartedAt);
```

漏掉这几行不会有任何报错，只会让查询在数据变多之后慢下来，而那时候已经很难归因。
`migrateAndValidate` 会比对索引，所以漏建会在迁移测试里红——这是靠测试兜住的，
不是靠人记得住。

**二、迁移测试必须覆盖每一条历史路径，不能只测「上一版 → 当前版」。**
用户从 1.0.0 直接装 1.2.0 是常态，不是例外。v3 的用例有四条：
`schemaAt(3)`（全新安装）、`schemaAt(1)` → 3、`schemaAt(2)` → 3，
外加在 v1 / v2 连接上写老数据后升上来断言「一条不丢、新列取到默认值」。

迁移测试的形态是 `SchemaVerifier(GeneratedHelper())` → `schemaAt(N)` →
`AppDatabase.forTesting(schema.newConnection())` → `verifier.migrateAndValidate(db, 当前版本)`。
要往老版本里造数据只能用 `customStatement` 跑裸 SQL，因为生成的 `schema_vN.dart`
里只有表类与 `DatabaseAtVN`，没有 Companion 类。

`schemaVersion`（数据库结构版本）与 `exportVersion`（导出文件格式版本）是**两套独立版本号**，
不要混用。前者管 SQLite 结构，后者管 JSON 结构。

---

## 7. 提醒架构

```
用户设置提醒时间
        │
        ▼
  Reminder 写入数据库（remind_at 为 UTC 毫秒）
        │
        ▼
  ReminderRepository.watchSources()  ← 与 tasks 做 innerJoin
        │  带上任务的标题与完成状态，调度器不用再查一次库
        ▼
  ReminderScheduler（应用层）
        │  buildReminderPlan() 纯函数算出「该排哪些、该撤哪些」
        │  用 timezone 把绝对时刻转成设备本地时区的 TZDateTime
        ▼
  flutter_local_notifications.zonedSchedule()
        │
        ▼
  系统通知（不依赖网络与后台进程）
```

关键约束：

- **`id` 由提醒 id 哈希而来**（`NotificationIds.forReminder`），哈希碰撞概率可忽略但确实存在；
  反过来「撤销」必须问系统 `pendingNotificationRequests()`，不能查自己记的账——
  应用被强杀后进程内记录是空的，而系统闹钟还在。
- **每次重算都重新问一次系统**（通知权限、精确闹钟权限），不缓存。用户刚从系统设置里
  改完权限回到应用，缓存会让你继续按旧状态排程。
- **重算必须串行**。提醒数据流与设置流几乎同时变化时会触发两轮重算，
  交错执行会出现「A 轮的撤销把 B 轮刚排上的通知撤掉」这类竞态。
- **不做增量 diff**。代价是每轮都全量 cancel + schedule，换来的是不用维护
  「进程内我排过什么」这份随时可能失真的账。cancel 一个没排过的 id 是幂等空操作。
- **不使用周期通知 API 做重复任务**。系统的周重复 API 无法表达「每周一三五」「每月第 3 个工作日」这类规则。
  重复提醒由 `buildReminderPlan` 以**最初锚点**为基准逐步推进（不是以上次结果递推，
  否则会累积漂移），逻辑在 `lib/core/notifications/reminder_plan.dart`，纯函数可单测。
  重复任务本身（完成一次自动生成下一次）仍待做，计划放在 `core/recurrence/`。
- **时区变化只能轮询**。`flutter_timezone` 只提供「读一次」，没有变更广播。
  实际触发点是应用回到前台（`AppLifecycleState.resumed`）与一个 10 分钟定时器兜底，
  见 `TimeZoneWatcher`。**不设时区会静默出错**：`initializeTimeZones()` 之后 `tz.local`
  是 UTC，东八区用户会晚 8 小时收到提醒且不抛任何异常。
- **权限拒绝要能降级**。用户拒绝通知权限时，应用必须仍完全可用，
  只在设置页与任务详情页给出可关闭的提示，不弹阻断式对话框。
- **Android 精确闹钟权限**（`SCHEDULE_EXACT_ALARM`）需按需申请；
  被拒绝时退化为非精确调度（`inexactAllowWhileIdle`）并在设置页说明，而不是静默不响。
- **强提醒用 `Notification.FLAG_INSISTENT`（裸值 4）**，靠 `AndroidNotificationDetails.additionalFlags`
  传下去。系统常量所以要给裸值，是因为插件对 `additionalFlags` 做的是 `notification.flags |= flag`。
  **系统的勿扰与静音会压制它**，这不是应用能绕开的，UI 上必须说清楚而不是让用户以为一定叫得醒。
- **通知渠道的重要性只在首次创建时生效**。改了渠道重要性必须让用户卸载重装才会变，
  所以渠道在 `_createChannels()` 里一次性建好，之后不改。
- **前台的常驻计时通知是「能力」不是「策略」**：`NotificationService.showOngoing()` 负责把它显示出来，
  谁在什么时候调它属于专注计时（F3）。`stopWithTask="false"` 是刻意的——
  把应用从最近任务里划掉不等于用户想结束专注。

---

## 8. 专注计时架构

```
用户点「开始专注」
        │
        ▼
  FocusPage  ──写库──▶  focus_sessions（startedAt / pausedMillis / plannedSeconds / …）
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
  watchRunning()                          watchRunning()
        │                                       │
        ▼                                       ▼
  首页恢复条 / AppBar 徽标            FocusNotificationSync
                                                │
                                                ▼
                                常驻通知（进度交给系统渲染）
                                    + 到点兜底提醒

读取方向：所有数字都由「时间戳 + DateTime.now()」现算，
没有哪一层存过「已经过了多久」。
```

`FocusTimerState`（`lib/core/focus/focus_timer.dart`）是唯一一份时间算术：纯 Dart、
不 import Flutter，所以它能在 `flutter test` 里直接跑，没有平台通道。时长边界与
休息轮次规则在 `lib/core/focus/focus_settings.dart`，同样纯函数。

关键约束：

- **界面不持有时间。** `FocusPage` 的 `Timer.periodic(1s)` 只做
  `setState(() => _now = DateTime.now())`，其余全是 `状态.elapsed(_now)` 的派生值。
  切后台、锁屏、被系统冻结都不会让数字漂——它们不来自帧计数。这个定时器只在
  有会话跑着时才建：空闲时也嘀嗒的话，整张 `SegmentedButton` 表单会在没人看的
  地方每秒重建一次。
- **`pausedMillis` 与 `pausedAt` 两个字段缺一不可。** 只存累计暂停时长的话，
  用户在暂停状态下被系统杀进程，重开后只能看到「从开始就一直跑着」，整段暂停
  被安静地算成专注时间——而杀进程恰恰是这套设计必须扛住的场景。
- **不变式「最多一条 `endedAt IS NULL`」由 `start()` 维持**：同一个事务里先把
  还没结束的那条收掉（停在新的开始时刻，按内核补算时长），而不是报错拒绝。
  调用方可能是崩溃恢复之后的重开，那条僵尸会话在语义上已被取代。补算而不是写 0：
  被取代的那一段是真实发生过的时间。
- **`logicalDate` 写入时冻结**（`logicalDateFor(now, midnightMode, midnightEndHour)`）。
  午夜模式下 23:50 开始、次日 00:20 结束的这段整段算在昨晚头上，收尾时不重算。
- **正在跑的那条 `actual_seconds` 还是 0**，统计要用 `elapsedSeconds(now)` 现算，
  否则「今天专注了多久」在界面上永远是 0，直到用户点结束才突然跳上来。
- **会话结束后的「记一笔」弹层要重读库里那份**（`FocusSessionRepository.findById`）：
  调用方手里那个对象是开始那一刻的快照，`actualSeconds` 还是 0、`completed` 还是 false。
- **走满收尾有 `_finishHandled` + `_busy` 双重守卫**：1 Hz 的 ticker 每秒都可能
  撞上同一个「已经走满」的状态，而收尾是一次写库加一次弹层。
- **常驻通知的进度交给系统渲染**（正计时给 `chronometerStart`，倒计时给 `countdown`）。
  应用每秒改一次通知文本是不行的：进程被系统压制时数字就停住了，用户看到的会是
  一个安静地卡住的计时器。
- **到点兜底提醒随暂停 / 恢复重排**，暂停时直接撤掉。留一条旧的在系统里，就会出现
  「已经暂停了却还是响了」，而恢复时终点本来就要往后挪。
- **设置的退路是启动快照，不是默认值构造。** `FocusPage` 读不到偏好流时退到
  `initialPreferencesProvider`（启动时真读过库的那份），而不是 `const AppPreferences()`：
  默认值只是「没读到」，用它顶替会让 `_start()` 拿默认时长开工、
  让倒计时收尾按 `autoStartNext == false` 停下——全发生在用户看不见的地方。
- **`focus_sessions.task_id` 用 `ON DELETE SET NULL`**：任务没了，但「我在这件事上
  花了两小时」是既成事实。
- 路由是 `/focus?task=<id>`：`/focus` 本身就是一条完整地址，归属任务可有可无，
  用查询参数比再多一段路径更贴合这件事。

### 8.1 统计与热力图

统计页（`lib/features/focus/stats_page.dart`）与热力图（`lib/features/focus/widgets/
heatmap.dart`）**只读 `focus_sessions`，不落汇总表**。会话记录本身就是事实，汇总
只是它的一个投影——加一张汇总表就多一份必须与事实保持同步的状态，而 1095 段
（365 天 × 3 段）的聚合在本机只要 20ms（`test/data/focus_stats_benchmark_test.dart`）。

口径全在 `lib/core/focus/focus_stats.dart` 里，纯函数、不 import Flutter：

- **窗口固定 365 天**（`kFocusStatsWindowDays`），一次把窗口内的切片读进来
  （`FocusSessionRepository.slicesBetween`），翻月份 / 切年视图只在内存里重排。
  统计页的口径因此是「最近一年」——页面上写明起止日期，不假装是全量。
- **「有记录」和「有时长」是两个口径。** `secondsByDay`（连续天数用它）丢掉 0 秒的
  日子；`summarizeDays` 保留 `sessions` 计数，热力图才分得出「来过但没计时」和
  「没有记录」。两者混用会把「打开计时器又立刻关掉」的一天算成连续的一天。
- **热力图阈值写死**（15 分钟 / 1 小时），不按当批数据算分位：分位数每次看都可能
  变，图例就写不住、跨周也没法比。五档分别对应 `FocusHeat` 的
  `none / zero / light / medium / heavy`，`none` 是唯一带描边的一档（没记录不等于 0）。
- **跨小时的会话按整点切开**（`secondsByHourOfDay`）：23:30 开始的 90 分钟是 30 分钟
  给 23 点、60 分钟给 0 点。整段归给起点会把「几点最坐得住」弄反。
- **小时桶是整个窗口里的同一个钟点**，不是每日平均。
- **已结束的会话用库里存的 `actual_seconds`**，不按 `startedAt` 重算——统计口径必须
  和当时记下的那一笔一致；只有还没结束的那条才用 `now` 补实时时长。

快照由 `focusStatsProvider`（**`autoDispose`**）提供。必须是 `autoDispose`：离开
统计页后监听者归零、快照丢掉，下次打开重读；否则「刚结束一段专注再打开统计页」
看到的还是应用启动那次算的数字，而且永远不会自己变。

热力图用 `LayoutBuilder` 算格子边长 + `Row` 手排，而不是 `CustomPainter`：一格要能点、
要带 `Semantics` 与 `Tooltip`，画成像素这些都得自己实现。代价是格子数就是 widget 数
（年视图 365 个），低端机滚动手感需真机确认。

### 8.2 成就徽章

徽章（`lib/core/focus/achievements.dart` + `lib/features/focus/achievements_page.dart`）
与统计同源：**都只读 `focus_sessions`，都不落表**。解锁状态是会话记录的派生值，存一份
就必然要与记录保持一致，还要额外回答「改了判定规则之后已解锁的还算不算」；现算的答案
显而易见——按新规则重算一遍。代价是每次进徽章页都要扫全部记录。

- **判定形状统一成「一个计数器 + 一个目标」**：`Achievement` 只带 `target` 与
  `int Function(AchievementFacts) valueOf`；解锁态、进度条、还差多少都从这两个值推出来，
  加一枚徽章是加一行 `const` 常量。
- **派生值一次算好**（`AchievementFacts`）：14 枚各扫一遍就是 14 遍 O(n)，现在一遍。
- **看全部历史，不跟统计页一样截 365 天**：「累计 100 小时」算的是一辈子的账，
  provider 直接 `slicesBetween(from: 0, to: today)`。
- **0 秒记录的口径分两类**：数条数的徽章把它算进去（一条 0 秒记录是「确实启动过计时器」
  的证据，与热力图的「来过没计时」同源），求时长的徽章只看秒数。
- **`value` 照实保留、`ratio` 封顶**：解锁之后仍显示真实累计，进度条由 `ratio` 收住。
- `achievementsProvider` 也必须 **`autoDispose`**：理由同统计页。
- 页面拿的是 `AchievementBoard`（事实 + 进度）而不是进度列表：进度永远 14 条，
  分辨不出「一条记录都没有」。
- F5 没有新增任何表、任何索引；查询只有 `slicesBetween` 一条，走 `focus_sessions`
  已有的 `logicalDate` / `startedAt` 索引。

### 8.3 桌面小组件

```
FocusSessionRepository.watchRunning() ──变化──┐
                                             ▼
                                   HomeWidgetSync（串行队列）
                                             │  算一份 HomeWidgetSnapshot
                                             ▼
                     MethodChannel now_todo/widget · update
                                             │
                                             ▼
                          HomeWidgetBridge.kt ──写──▶ SharedPreferences
                                             │                  │
                                             ▼                  ▼
                          FocusWidgetProvider ──▶ RemoteViews（今天时长 + 七天柱子）

应用不在时：系统的 updatePeriodMillis（下限 30 分钟）触发重画，
读的还是上次那份快照。
```

- **不引 `home_widget`，自写通道**：少一个依赖、少一套要跟着调的默认样式；而
  「进程被杀后仍显示上次数据」本来就要求数据落在平台侧（SharedPreferences），
  插件并不能省掉这一步。代价是四份资源 + 两个 Kotlin 文件自己维护。
- **小组件不查库**，只画应用推过去的那份快照。让 Kotlin 侧读 sqlite 等于把数据库格式、
  迁移、加锁搬到平台层，那是另一套要跟着 drift 一起升级的东西。
- **两套配色一起发**（`buildWidgetPayload` 里的 `*Light` / `*Dark`），由 Kotlin 按系统
  `uiMode` 挑一套。小组件的深浅色跟的是系统夜间模式，不是应用里那份设置——
  用户在系统里切模式时应用可能压根没在跑。
- **过期判断用快照里的 `today` 与当天零点比对**：对不上就换成「还没更新今天的记录 /
  打开应用刷新」，不拿昨天的数字冒充今天。30 分钟的系统刷新下限本来也不够用来做
  「每分钟更新」，它只负责跨零点后换文案。
- **`levels` 传的是一串下标**（`0`–`4`），Kotlin 侧按 `kFocusHeatOrder` 查色。这个顺序
  因此是接口的一部分：改了它，已经装在桌面上的旧小组件会把颜色认错，
  `test/core/theme/heat_colors_test.dart` 咬住这一点。
- **触发点只有两个，不开定时器**：启动一次 + 每次会话变化一次，串行队列的理由同
  `FocusNotificationSync`；`RemoteViews` 每帧都要过一次 IPC，「每秒更新」在这里比通知更糟。
- **通道失败不打扰用户**：`MissingPluginException`（平台侧还没挂上）静默，
  其他 `PlatformException` 只 `debugPrint`。小组件是增强功能，没它应用照常跑。
- **平台侧声明由 `test/android/` 的测试咬住**：它们读仓库里的文本文件（`flutter test`
  的工作目录就是包根），断言清单里的 receiver、`updatePeriodMillis`、布局里每个
  `R.id` 都存在、**Dart 发过去的每个键 Kotlin 侧都读了**。这类漂移的症状全是静默失效，
  静态断言比等真机复现便宜。

---

## 9. 导入导出格式

导出为单个 JSON 文件，UTF-8，`exportVersion` 标识格式版本。
下面的字段名以真实的表结构为准（每张表一个数组，键用驼峰）：

```json
{
  "exportVersion": 1,
  "exportedAt": 1735689600000,
  "app": { "name": "now_todo", "version": "1.0.0", "schemaVersion": 4 },
  "data": {
    "taskLists": [
      { "id": "...", "name": "工作", "color": 4281545523, "isBuiltIn": false,
        "sortOrder": 0, "createdAt": 0, "updatedAt": 0 }
    ],
    "tags": [ { "id": "...", "name": "紧急", "color": 4292826954, "createdAt": 0 } ],
    "tasks": [
      {
        "id": "...", "title": "...", "note": "", "dueDate": 1735689600000,
        "dueDateHasTime": true, "priority": 2, "status": 0, "listId": "...",
        "recurrenceRuleId": null, "createdAt": 0, "updatedAt": 0,
        "completedAt": null, "estimatedPomodoros": null
      }
    ],
    "taskTags": [ { "taskId": "...", "tagId": "..." } ],
    "subtasks": [
      { "id": "...", "taskId": "...", "title": "...", "isDone": false,
        "sortOrder": 0, "createdAt": 0 }
    ],
    "reminders": [
      { "id": "...", "taskId": "...", "remindAt": 0, "repeatType": 0,
        "enabled": true, "createdAt": 0 }
    ],
    "recurrenceRules": [
      { "id": "...", "frequency": 2, "interval": 1, "startsOn": 0,
        "byWeekday": "1,3,5", "byMonthDay": null, "endDate": null,
        "endCount": null, "createdAt": 0 }
    ],
    "focusSessions": [
      { "id": "...", "taskId": null, "startedAt": 0, "endedAt": null,
        "pausedMillis": 0, "pausedAt": null, "plannedSeconds": 1500,
        "actualSeconds": 0, "kind": 0, "timerMode": 1, "logicalDate": 0,
        "completed": false, "note": null }
    ],
    "settings": {
      "themeMode": 0, "defaultView": 0, "notificationsEnabled": true,
      "strongReminders": false, "focusMinutes": 25, "shortBreakMinutes": 5,
      "longBreakMinutes": 15, "roundsBeforeLongBreak": 4, "autoStartNext": false,
      "defaultTimerMode": 1, "midnightMode": false, "midnightEndHour": 4
    }
  }
}
```

设计要点：

- **扁平化**：每张表一个数组，不做嵌套结构。嵌套结构在格式演进时极易产生歧义。
- **字段名与领域模型一致**：导入导出层不做字段重命名，减少一层映射 Bug。
- **颜色存 ARGB 整数**，与库里一致（不转 `#RRGGBB` 字符串：多一次转换就多一处会错的地方）。
- **导入必须整体校验后再落库**：任何一条记录校验失败就整体拒绝，并给出可读的错误位置。
  半成功状态比失败更糟——用户无法判断数据是否完整。
- **导入顺序由外键决定**：`taskLists` / `tags` / `recurrenceRules` 先，`tasks` 后，
  `subtasks` / `reminders` / `taskTags` / `focusSessions` 最后。
- **导入策略**：按 `id` 判断冲突，提供「合并」与「覆盖（清空后导入）」两种模式，
  默认**合并**，且整体在一个数据库事务内完成。
- **合并的取舍只看时间戳**：`_fileWins(本地, 文件) = 本地没有 || 文件严格更新`。**相等时保留本地**，
  这样「同一份文件导入两次，第二次什么都不改」；本地独有的行一律不动。各表用的时间戳：
  清单 / 任务用 `updatedAt`，标签 / 子任务 / 提醒 / 重复规则用 `createdAt`，
  专注记录没有时间戳列，用 `startedAt`（一段会话的身份就是它什么时候开始的）。
- **标签按名字认亲**：`tags.name` 是唯一索引。本地已有同名标签（id 不同）时不插新的，
  以本地那行为准，同时把文件里的 `tagId` 映射成本地 id 再写 `taskTags`
  ——不映射的话外键会拒掉整个导入。
- **没结束的专注记录不搬**：`endedAt == null` 的行导入时跳过。那是设备上的当前状态，
  搬过来会凭空多出一段「正在计时」，两条并存的会话还会让「当前会话」查询失去单值性。
- **设置是设备偏好，不是任务数据**：合并模式只在**本地还是出厂值时**才接受文件里的设置
  （`AppPreferences.isDefault`，判 12 项、不看 `initializedAt`——那是第一次启动就会被写上的记账）；
  覆盖模式整份替换。导入别人的备份不该悄悄改掉我的主题和专注时长。
- **覆盖模式先按反外键序清空八张表**（`app_settings` 不动），全部写完再 `ensureInitialized()`：
  文件里没有内置收件箱时，应用也不会因此失去默认清单。
- **版本兼容**：`exportVersion` 高于当前应用支持的上限时拒绝导入并提示升级应用。
  低于时走显式升级函数链（`v1 → v2 → v3`），不允许隐式猜测。
  文件里的 `app.schemaVersion` 只是给人看的信息，决定「能不能读」的只有 `exportVersion`。
- **`app` 段读得很宽容**：它是给人看的信息块，缺了或类型不对都不影响导入，只有 `exportVersion` 是硬门槛。

---

## 10. 主题与设计

- 使用 Material 3。
- 主题模式：`ThemeMode.system` / `light` / `dark`，默认跟随系统。用户选择持久化在 `settings` 表。
- 颜色与间距不在 Widget 里硬编码，集中在 `lib/app/theme/` 的 `ThemeData` 与语义化常量中。
- 系统强调色仅在 Material 3 支持范围内使用，不引入第三方主题引擎（首版）。

---

## 11. 错误处理

- 仓储层返回领域结果，**不向 UI 抛原始数据库异常**。
- 可预期的失败（导入文件格式错误、磁盘写入失败）用显式结果类型表达，配可读的中文提示。
- 不可预期的异常集中记录在应用层日志中；**日志内容不得包含用户任务文本**（见 PRD 隐私章节）。
- 首版不上报崩溃到任何服务器。匿名崩溃统计是增强项，且必须默认关闭。

---

## 12. 测试策略

| 层次 | 范围 | 工具 |
| --- | --- | --- |
| 单元测试 | 重复规则计算、提醒时间换算、导入校验、日期工具、**计时内核与时长边界**、**统计聚合**、**徽章判定** | `flutter_test` |
| 仓储测试 | 增删改查、级联删除、事务回滚 | `flutter_test` + 内存 SQLite（`NativeDatabase.memory()`） |
| 迁移测试 | 每个历史 `schemaVersion` → 当前版本 | `drift_dev schema` 导出 + `flutter_test` |
| Widget 测试 | 空态、主流程、错误态、**状态机** | `flutter_test`，注入假仓储 |
| 集成测试 | 端到端核心流程 | `integration_test`（`reminder_delivery_test.dart` 验证提醒送达；`end_to_end_test.dart` 走「建任务 → 加标签 → 设提醒 → 完成 → 导出」并要求真机） |
| 平台声明 | Android 清单、App Widget 配置与布局、Dart↔Kotlin 的键名约定 | `flutter_test` 直接读仓库里的文本文件（`test/android/`） |

**平台侧为什么也进测试。** 清单里的权限、`foregroundServiceType`、`stopWithTask`、
小组件的 `updatePeriodMillis`、布局里的 id —— 这些漏一条的症状全是静默失效：
通知不出现、划掉 App 后消失、Android 14+ 抛 `SecurityException`、桌面上那块是空白。
而 `flutter test` 的工作目录就是包根，读文件断言比等真机复现便宜得多。
同理，`test/android/home_widget_test.dart` 会拿 `buildWidgetPayload()` 发出的键名
逐个去 Kotlin 源码里找字面量——这类跨语言的约定没人会在编译期替我们检查。
`test/android/app_icon_test.dart` 更进一步：它手工解析 PNG 的 IHDR 断言尺寸与颜色类型
（商店图不许带透明通道），并用 `dart:ui` 解码前景层逐像素量最远半径，确认符号收在
66dp 安全圆内——「比例写对了但坐标写歪」只有量像素才发现得了。

**端到端那一条跑真实启动路径。** `lib/main.dart` 的 `main({List<Override> overrides})`
就是为它留的缝：用例只把碰系统 UI 的部件换掉（分享面板在自动化里点不到），
数据库、通知、时区全是真的。其中提醒那一段刻意绕开界面的时间选择器——从 `ReminderRepository`
写一条，再问系统要 `pendingNotificationRequests()`，因为要证明的是「提醒进库 → 系统里真的多了一个闹钟」，
而在系统对话框里拨表盘既脆又没有信息量。

**必须测的边界**（PRD 风险章节点名的高危区）：

- 重复任务：跨月、月末（1/31 → 2/28）、闰年、按周几重复、有结束日期与按次数结束。
- 提醒：跨时区、夏令时切换日、设备时区变更后重新调度。
- 导入导出：空库导出、含全部关联的导出、损坏 JSON、版本过高、版本过低、id 冲突合并。
  已落地在 `test/core/backup/backup_codec_test.dart`（31 条：往返、根与版本、逐字段报错位置、
  引用完整性）、`test/data/backup_repository_test.dart`（16 条：覆盖清空、data 段深比较、
  合并的新旧取舍与幂等、同名标签认亲、设置取舍、单事务回滚）、
  `test/features/settings_backup_test.dart`（7 条：导出成功与失败、坏文件、取消、两种模式）。
  回滚那条是**故意喂一条标题为空串的任务**：codec 只管类型与引用，长度约束归数据库，
  要让「写到一半炸掉」真的发生，只能靠库自己拦。
- 大数据量：1000 条任务下列表滚动与搜索响应（`test/data/search_benchmark_test.dart`）；
  一年 365 天 × 3 段的专注聚合耗时（`test/data/focus_stats_benchmark_test.dart`，本机读库 3ms / 聚合 20ms）。
- 专注：跨午夜与可配置边界小时、暂停中被杀进程、会话收尾时刻的时长口径。
- 统计：窗口补齐（含闰年 2 月）、「有记录但 0 秒」与「无记录」区分、小时桶的跨整点切分、
  连续天数「今天还没开始不算断」。
- 徽章：判定只吃会话记录（同一批记录重算两次结果一样）、0 秒记录只算「启动过」不给时长、
  「今天」变化只影响当前连续而不影响历史累计、仓库里不存在解锁记录表。
- 桌面小组件：七天窗口跨月跨年、快照里的 `today` 对不上当天时要走过期文案、
  档位下标与 `kFocusHeatOrder` 一一对应（它是接口的一部分）。

**三条会反复踩的测试写法**：

- **drift 的 `close()` 不能放进 `tearDown`。** widget 用例跑在 fake async 区里，
  用例体返回后框架会先拆树再断言「不许有未完成的定时器」，而 drift 取消订阅时排的
  清理定时器永远不会跑，于是每个用例都以 `A Timer is still pending…` 收尾。
  先 `await tester.runAsync(db.close)`、而且放在用例体最后一步，就不排那个定时器了。
  放进 `tearDown` 更糟：那时定时器已排下，`close()` 会永远等下去，整个文件挂死。
- **有每秒 ticker 的页面不能用 `pumpAndSettle`**（帧永远排不空，会一路等到超时），
  改成手动推固定帧数；要等 ticker 真的走一次，就推够 1 秒以上。
- **页面里直接 `await` 平台插件 = 这个页面在 widget 测试里用不了 `pumpAndSettle`。**
  平台通道在测试环境没有对端，回复要靠真实事件循环，而用例跑在 fake async 区，
  于是那个 Future 永远挂着、连转圈动画的帧也排不空（现象是 `pumpAndSettle timed out`）。
  `PackageInfo.fromPlatform()` 就是这么把设置页卡住的，修法是把设备上下文挪进 provider
  （`appVersionProvider`）——它是环境事实，不是页面逻辑。

---

## 13. 构建与发布

- CI（GitHub Actions）在每次 PR 上执行：`dart format` 校验 → `flutter analyze` → `flutter test` → Android debug 构建。
- **生成的 `*.g.dart` 提交入库**，克隆后可直接构建；CI 与本地发布脚本都会重跑一次
  `build_runner` 校验生成产物与源码一致。**校验范围只看 `lib/` 与 `test/`**：
  `pubspec.lock` 里 116 行 `url:` 记的是「依赖从哪个 host 拉下来」，开发机设了
  `PUB_HOSTED_URL=https://pub.flutter-io.cn` 走镜像、GitHub runner 走 pub.dev，
  两边会互相改写这些行——依赖版本由 lock 钉着，没有真的变化，判整棵工作区只会让这道门误报。
  在任何一台机器上手动 diff 时同理：看到 `pubspec.lock` 全是 url 行在动，那不是你改坏了什么。
- Android 应用身份：`applicationId = "io.github.hesperyx.nowtodo"`（**上架后无法更改**，
  所以跟着不会过期的 GitHub 账号走，而不是域名或自造品牌词）。`namespace` 与它保持一致，
  清单里的 `.MainActivity` / `.FocusWidgetProvider` 按 `namespace` 解析，改一处即可。
- 正式签名：`android/key.properties`（已被 `android/.gitignore` 挡住）提供
  `storeFile` / `storePassword` / `keyAlias` / `keyPassword`，模板见 `android/key.properties.example`。
  没有这个文件时 release 构建退回 debug 签名——能构建、不能上架，两种情况共用一个命令。
- iOS：**当前不在目标平台内**。首版只发 Android，`ios/` 目录已移除（见 `docs/PRD.md`
  末尾的「范围变更记录」）。将来恢复 iOS 时需要重新 `flutter create --platforms=ios .`、
  重新确认 `bundle id`，并按 App Store 审核要求调整捐赠入口（`lib/features/about/about_page.dart`
  里的 iOS 分支与 `AppConstants.donationUrl` 的注释已为此预留）。
- **发布前检查一条命令**：`powershell -File tool/release_check.ps1 -Apk`——重跑代码生成并确认
  工作区没有变化、格式校验、静态分析、全部测试，再打一次 release 包用 `aapt` 核对包名、
  应用名与「不许出现 `INTERNET` 权限」。
  `dart format` 固定用 Flutter 自带的 SDK：独立安装的 dart（本机实测 3.11.5）与 Flutter 3.35.5
  自带的 3.9.2 不是同一个格式化器，用错版本会让这道门变成假信号。
  生成产物那一步是**生成前后各拍一次工作区快照再比差**：只认生成器带来的变化，
  手上没写完的改动不会让它误报。这条门值得留在本地——改了 Drift 表的文档注释却忘了重跑
  `build_runner` 时，`*.g.dart` 会和源码对不上，而 `analyze` 与 `test` 都不会响。
- 图标与商店特色图片都是脚本生成的（`tool/app_icon/`），产物提交入库；脚本自带安全区自检，
  见 M8 一节的实现说明。商店文案与分级问卷底稿在 [STORE.md](STORE.md)。
- 发布前检查清单见 [MILESTONES.md](MILESTONES.md) 的 M8。

---

## 14. 未来扩展点

刻意**不提前实现**，但确认当前结构不会挡住：

| 扩展 | 已预留的空间 |
| --- | --- |
| 云同步 / 多设备 | 主键为客户端 UUID；每行有 `updated_at`；导出格式扁平且带版本 |
| 桌面小组件 | `go_router` 支持深链接，可直接跳转到指定视图 |
| 日历视图 | 数据层已按 UTC 毫秒存储，视图层自行聚合 |
| 多语言 | 文案集中在 `core/constants/`，迁移到 `l10n/` 是纯搬移 |
| 多主题 | 主题集中在 `lib/app/theme/` |
| CSV 导出 | 导出层与领域模型解耦，加一个序列化器即可 |

引入上述任一功能前，请先更新 [PRD.md](PRD.md) 并开 Issue 讨论——它们都不在首版范围内。
