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
| `tasks` | `id` `title` `note` `due_date` `priority` `status` `list_id` `created_at` `updated_at` `completed_at` `recurrence_rule_id` `sort_order` | `priority`: 0=无 1=低 2=中 3=高；`status`: 0=未完成 1=已完成 2=已归档；`due_date` 存 UTC 毫秒时间戳，可为空 |
| `task_lists` | `id` `name` `color` `sort_order` `created_at` `updated_at` | 清单（PRD 中的 Checklist/List） |
| `tags` | `id` `name` `color` `created_at` | 标签 |
| `task_tags` | `task_id` `tag_id` | 多对多关联表，复合主键 |
| `subtasks` | `id` `task_id` `title` `is_done` `sort_order` `created_at` | 子任务，父任务删除时级联删除 |
| `reminders` | `id` `task_id` `remind_at` `repeat_type` `enabled` `created_at` | 本地提醒 |
| `recurrence_rules` | `id` `frequency` `interval` `by_weekday` `end_date` `count` | 重复规则；`by_weekday` 存逗号分隔的 1–7 |
| `settings` | `key` `value` | 键值表，存主题、默认视图、提醒开关、`exportVersion` 等 |

### 5.2 关键设计决策

**时间一律存 UTC 毫秒时间戳，不存本地时间字符串。**
跨时区、跨夏令时是提醒类应用最容易出 Bug 的地方。展示时再转本地时区（`intl`），
调度通知时用 `timezone` 转换。存储层永不出现「本地时间」。

**`updated_at` 每次写入必须刷新。**
未来若做同步或冲突合并，这是唯一可用的版本依据。

**删除策略**：首版采用硬删除。软删除（`deleted_at`）只在引入同步时才需要，
提前引入会让所有查询都要带 `WHERE deleted_at IS NULL`，属于为不存在的需求付成本。

**索引**：`tasks(status)`、`tasks(due_date)`、`tasks(list_id)`、`subtasks(task_id)`、
`reminders(task_id)`、`task_tags(tag_id)`。首页「今日」视图是最高频查询，
`due_date` 索引必须有。

**级联**：`tasks` 删除 → 级联清理 `subtasks`、`reminders`、`task_tags`。
用外键约束 + `ON DELETE CASCADE`，不靠应用层记得手动删。

---

## 6. 数据库迁移

数据是用户资产，迁移是最高风险操作。

- **每次改表结构必须同时**：提升 `schemaVersion` → 写 `MigrationStrategy.onUpgrade` → 补迁移测试。
- 迁移测试用 Drift 的 schema 导出（`dart run drift_dev schema dump`）做逐版本验证。
- **禁止**在 `onUpgrade` 里 `deleteTable` / 重建库 / 静默丢列。
- **禁止**在没有测试的情况下发布带 `schemaVersion` 变更的版本。
- 无法自动迁移的破坏性变更必须：先在应用内提示用户导出备份，再提供显式的迁移入口。

`schemaVersion`（数据库结构版本）与 `exportVersion`（导出文件格式版本）是**两套独立版本号**，
不要混用。前者管 SQLite 结构，后者管 JSON 结构。

---

## 7. 提醒架构

```
用户设置截止时间 / 提醒时间
        │
        ▼
  Reminder 写入数据库（remind_at 为 UTC 毫秒）
        │
        ▼
  ReminderScheduler（应用层）
        │  用 flutter_timezone 取当前设备时区
        │  用 timezone 把 UTC → 设备本地 tz 的绝对时刻
        ▼
  flutter_local_notifications.zonedSchedule()
        │
        ▼
  系统通知（不依赖网络与后台进程）
```

关键约束：

- **不使用周期通知 API 做重复任务**。系统的周重复 API 无法表达「每周一三五」「每月第 3 个工作日」这类规则。
  重复任务由应用层在任务完成时计算下一次实例并重新调度，逻辑集中在 `core/recurrence/`，可单元测试。
- **时区变化必须重新调度**。监听 `flutter_timezone` 的时区变化，以及应用启动时的时区校验；
  若设备时区与上次调度时不一致，全部未过期提醒重新计算。
- **权限拒绝要能降级**。用户拒绝通知权限时，应用必须仍完全可用，
  只在设置页与任务详情页给出可关闭的提示，不弹阻断式对话框。
- **Android 精确闹钟权限**（`SCHEDULE_EXACT_ALARM`）需按需申请；
  被拒绝时退回非精确调度并在 UI 上说明，而不是静默不响。

---

## 8. 导入导出格式

导出为单个 JSON 文件，UTF-8，`exportVersion` 标识格式版本。

```json
{
  "exportVersion": 1,
  "exportedAt": 1735689600000,
  "app": { "name": "now_todo", "version": "1.0.0", "schemaVersion": 1 },
  "data": {
    "taskLists": [ { "id": "...", "name": "工作", "color": "#4F46E5", "sortOrder": 0 } ],
    "tags": [ { "id": "...", "name": "紧急", "color": "#DC2626" } ],
    "tasks": [
      {
        "id": "...", "title": "...", "note": "", "dueDate": 1735689600000,
        "priority": 2, "status": 0, "listId": "...",
        "createdAt": 0, "updatedAt": 0, "completedAt": null,
        "recurrenceRuleId": null, "sortOrder": 0
      }
    ],
    "taskTags": [ { "taskId": "...", "tagId": "..." } ],
    "subtasks": [ { "id": "...", "taskId": "...", "title": "...", "isDone": false, "sortOrder": 0 } ],
    "reminders": [ { "id": "...", "taskId": "...", "remindAt": 0, "repeatType": 0, "enabled": true } ],
    "recurrenceRules": [ { "id": "...", "frequency": 2, "interval": 1, "byWeekday": "1,3,5", "endDate": null, "count": null } ]
  }
}
```

设计要点：

- **扁平化**：每张表一个数组，不做嵌套结构。嵌套结构在格式演进时极易产生歧义。
- **字段名与领域模型一致**：导入导出层不做字段重命名，减少一层映射 Bug。
- **导入必须整体校验后再落库**：任何一条记录校验失败就整体拒绝，并给出可读的错误位置。
  半成功状态比失败更糟——用户无法判断数据是否完整。
- **导入策略**：按 `id` 判断冲突，提供「合并（保留较新的 `updatedAt`）」与「覆盖（清空后导入）」两种模式，
  默认**合并**，且整体在一个数据库事务内完成。
- **版本兼容**：`exportVersion` 高于当前应用支持的上限时拒绝导入并提示升级应用。
  低于时走显式升级函数链（`v1 → v2 → v3`），不允许隐式猜测。

---

## 9. 主题与设计

- 使用 Material 3。
- 主题模式：`ThemeMode.system` / `light` / `dark`，默认跟随系统。用户选择持久化在 `settings` 表。
- 颜色与间距不在 Widget 里硬编码，集中在 `lib/app/theme/` 的 `ThemeData` 与语义化常量中。
- 系统强调色仅在 Material 3 支持范围内使用，不引入第三方主题引擎（首版）。

---

## 10. 错误处理

- 仓储层返回领域结果，**不向 UI 抛原始数据库异常**。
- 可预期的失败（导入文件格式错误、磁盘写入失败）用显式结果类型表达，配可读的中文提示。
- 不可预期的异常集中记录在应用层日志中；**日志内容不得包含用户任务文本**（见 PRD 隐私章节）。
- 首版不上报崩溃到任何服务器。匿名崩溃统计是增强项，且必须默认关闭。

---

## 11. 测试策略

| 层次 | 范围 | 工具 |
| --- | --- | --- |
| 单元测试 | 重复规则计算、提醒时间换算、导入校验、日期工具 | `flutter_test` |
| 仓储测试 | 增删改查、级联删除、事务回滚 | `flutter_test` + 内存 SQLite（`NativeDatabase.memory()`） |
| 迁移测试 | 每个历史 `schemaVersion` → 当前版本 | `drift_dev schema` 导出 + `flutter_test` |
| Widget 测试 | 空态、主流程、错误态 | `flutter_test`，注入假仓储 |
| 集成测试 | 端到端核心流程 | `integration_test`（M8 阶段引入） |

**必须测的边界**（PRD 风险章节点名的高危区）：

- 重复任务：跨月、月末（1/31 → 2/28）、闰年、按周几重复、有结束日期与按次数结束。
- 提醒：跨时区、夏令时切换日、设备时区变更后重新调度。
- 导入导出：空库导出、含全部关联的导出、损坏 JSON、版本过高、版本过低、id 冲突合并。
- 大数据量：1000 条任务下列表滚动与搜索响应。

---

## 12. 构建与发布

- CI（GitHub Actions）在每次 PR 上执行：`dart format` 校验 → `flutter analyze` → `flutter test` → Android debug 构建。
- **生成的 `*.g.dart` 提交入库**，克隆后可直接构建；CI 校验生成产物与源码一致。
- Android：`applicationId` 当前为占位值 `com.nowtodo`（`flutter create --org com.nowtodo`），
  **首次上架前必须确认为最终域名反写**，因为上架后无法更改。
- iOS：**当前不在目标平台内**。首版只发 Android，`ios/` 目录已移除（见 `docs/PRD.md`
  末尾的「范围变更记录」）。将来恢复 iOS 时需要重新 `flutter create --platforms=ios .`、
  重新确认 `bundle id`，并按 App Store 审核要求调整捐赠入口（`lib/features/about/about_page.dart`
  里的 iOS 分支与 `AppConstants.donationUrl` 的注释已为此预留）。
- 发布前检查清单见 [MILESTONES.md](MILESTONES.md) 的 M8。

---

## 13. 未来扩展点

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
