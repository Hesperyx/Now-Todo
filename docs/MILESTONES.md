# 里程碑

本文档把 [PRD](PRD.md) 的首版范围拆成可交付、可验收的阶段。

**规则**：

- 每个里程碑的「验收标准」必须**全部**满足才可标记完成。不满足就顺延，不放水。
- 不在当前里程碑范围内的功能，一律不做——即使顺手。范围蔓延是 PRD 点名的头号风险。
- 增强项（小组件、日历、统计、多语言、无障碍）**不在 1.0.0 的里程碑序列内**，见文末。

状态图例：`已完成` · `进行中` · `未开始`

---

## M0 · 仓库与工程基线

**状态**：已完成

**交付物**

- Flutter 项目骨架，目标平台 Android，另保留 Windows 桌面用于开发预览（iOS 见 `docs/PRD.md` 末尾「范围变更记录」）。
- `docs/PRD.md`、`docs/ARCHITECTURE.md`、`docs/MILESTONES.md`。
- MIT `LICENSE`、`README.md`、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`CHANGELOG.md`。
- 收紧的 `analysis_options.yaml`（strict-casts / strict-inference / strict-raw-types + 加固 lint）。
- 依赖锁定并验证解析成功（详见 ARCHITECTURE §4）。
- `.github/` 下的 CI 工作流与 Issue / PR 模板。

**验收标准**

- [x] `flutter pub get` 成功
- [x] 仓库治理文件齐备，符合 PRD「开源与捐赠」章节要求
- [x] CI 工作流在 PR 上触发（格式检查 / 静态分析 / 单元测试 / Android 构建）
- [x] 在单人开发场景下人工执行过一遍 CI 的全部命令

  > 2026-10-06 本机实测：`flutter pub get` → `dart run build_runner build`（跑完 `git diff` 无输出，
  > 产物哈希 `4A8AADBE…D56E5B` 前后一致）→ `dart format --output=none --set-exit-if-changed .`（退出 0）
  > → `flutter analyze`（`No issues found!`）→ `flutter test`（68 条全绿），全部通过。
  >
  > **例外**：CI 里的 `flutter build apk --debug` 未能在这台开发机上执行——本机 Android SDK
  > 缺 `cmdline-tools` 且 licenses 未接受。该步骤目前只在 CI 与已授权的开发机上得到验证。

---

## M1 · 数据层

**状态**：已完成（2026-10-07 校准）

**交付物**

- `lib/data/database/` 下全部 Drift 表定义：`tasks`、`task_lists`、`tags`、`task_tags`、`subtasks`、`reminders`、`recurrence_rules`、`focus_sessions`、`app_settings`。✅ 9 张表齐备
  （最初写的表名 `settings` 与真实表名 `app_settings` 不符，已订正；`focus_sessions` 随 F2 加入）
- 外键约束与 `ON DELETE CASCADE`（任务删除时级联清理子任务、提醒、标签关联）。✅ 已开启 `PRAGMA foreign_keys`；
  `subtasks` / `task_tags` / `reminders` 的 `taskId` 均为 `KeyAction.cascade`；
  `tasks.listId`、`tasks.recurrenceRuleId`、`focus_sessions.taskId` 为 `setNull`
- 索引：✅ **14 条**全部存在——`tasks(status)` `tasks(due_date)` `tasks(list_id)`
  `tasks(recurrence_rule_id)` `subtasks(task_id)` `subtasks(task_id, sort_order)`
  `reminders(task_id)` `reminders(remind_at)` `task_lists(sort_order)` `tags(name)`（唯一）
  `task_tags(tag_id)` `focus_sessions(logical_date)` `focus_sessions(task_id)` `focus_sessions(started_at)`
- 每个聚合的 DAO，以及 `lib/data/repositories/` 下的仓储接口与实现。⚠️ **不按字面实现，且这是最终决策**：
  项目只做仓储层，没有 `DatabaseAccessor` 子类形式的 DAO，理由见下面的「实现说明」
- 领域模型与枚举。✅ `lib/core/models/enums.dart` 含 **8 个**枚举：`TaskPriority` / `TaskStatus` /
  `RecurrenceFrequency` / `ReminderRepeatType` / `ThemeModeSetting` / `DefaultView` /
  `FocusSessionKind` / `FocusTimerMode`
- `MigrationStrategy` + `dart run drift_dev schema dump` 生成的 schema 快照。✅ `lib/data/database/app_database.dart:46`
  的 `schemaVersion => 4`、`:49` 起的 `MigrationStrategy` 逐版本迁移；`drift_schemas/drift_schema_v1..v4.json`
  四条快照齐全，`test/data/migration_test.dart` 8 条用例守着「全新安装 / 各历史版本升到最新 / 升级不丢数据」

**验收标准**

- [x] `AppDatabase` 能在内存模式（`NativeDatabase.memory()`）下打开，用于测试
- [x] 任务删除后，其子任务 / 提醒 / 标签关联记录全部消失（有测试）——三条各有对应用例：
  `test/data/task_repository_test.dart:218`（子任务）、`test/data/task_repository_test.dart:300`（标签关联，
  同时断言标签本身还在）、`test/data/reminder_repository_test.dart:200`（提醒）
- [x] 仓储层不向上层抛出 Drift 生成类型（`features/` 的 import 静态检查通过）
- [x] `flutter analyze` 零告警
- [x] 仓储测试覆盖增删改查与级联删除——增删改查全覆盖；级联删除覆盖上述三条 CASCADE，
  另加两条 `SET NULL`：`test/data/focus_session_repository_test.dart:125`（删任务后专注历史保留）、
  `test/data/task_recurrence_test.dart:307`（删规则后历史实例还在）

**实现说明**（2026-10-07 校准）

- **只做仓储，不做 DAO。** Drift 的 DAO 是 `DatabaseAccessor` 的子类，它会把 drift 生成的类型
  （`TasksCompanion`、`$TasksTable`）直接摊到调用点上；而 §3 定下的分层是「`lib/features/**` 不许 import
  drift」。中间已经有一个仓储层做这件事，再套一层 DAO 只会多一段没人读的转发代码。
- **级联删除全靠外键**，应用层一行清理代码都不写。手动清理漏一处就是永久孤儿行，而且不会报错；
  外键约束漏了会当场抛。代价是测试与运行都必须开着 `PRAGMA foreign_keys = ON`
  （在 `beforeOpen` 里，见 `app_database.dart`）。
- **删除是可撤销的**：`restore(TodoTask)` 连同 id、`createdAt`、标签关联一起还原，所以真正的删除
  只在用户确认之后发生一次。

---

## M2 · 任务核心闭环

**状态**：已完成（2026-10-07 校准）

> **校准说明**：本节代码早于文档状态落地，2026-10-07 逐条核对后补齐勾选。
> 证据：`lib/features/home/home_page.dart`（四视图、搜索、排序、逾期筛选、划走删除 + 撤销）、
> `lib/features/task_editor/task_editor_page.dart`（新建 / 编辑）、`test/widget_test.dart` 5 条用例。

**交付物**

- 首页与「全部」视图：任务列表、完成勾选、删除、空态。
- 创建 / 编辑任务页：标题、备注、截止日期、优先级。
- 完成与恢复任务；已完成视图。
- 「今日」视图：按截止日期聚合当天到期与逾期任务。
- 快速新增入口（PRD 成功标准：**创建一次任务不超过 3 步**）。

**验收标准**

- [x] 冷启动后 3 步内可创建一条带截止日期的任务
- [x] 断网状态下，新增 / 编辑 / 删除 / 完成 / 恢复全部可用（release 包不含 `INTERNET` 权限，本就没有联网路径）
- [x] 勾选完成与取消完成即时反映在列表与已完成视图
- [x] 删除有撤销能力或二次确认，不出现误删即永久丢失（划走删除 + Snackbar 撤销，刻意不做二次确认弹窗）
- [x] 空态有明确引导文案，不是空白页（`lib/features/home/widgets/task_empty_state.dart`）
- [x] Widget 测试覆盖空态与新增流程

---

## M3 · 组织能力

**状态**：已完成（2026-10-07）

**交付物**

- 清单：创建、重命名、改色、排序、删除（含其中任务的处置提示）。
- 标签：创建、改名、改色、删除；任务可绑多个标签。
- 搜索：按标题与备注的模糊匹配，实时结果。
- 排序：按截止日期 / 创建时间 / 优先级 / 标题。
- 筛选：按清单、标签、优先级、完成状态组合筛选。

**实现说明**

- 管理入口：`lib/features/organization/` 下的 `lists_page.dart`（拖拽排序走 `ReorderableListView`）、
  `tags_page.dart`（不排序，标签跨清单，顺序按名字）、`name_color_dialog.dart`（新建与编辑共用一个
  弹窗，只有标题和初值不同）。首页「更多」菜单进这两页。
- 颜色：新加的 `lib/core/theme/entity_palette.dart` 给八档中间调，**库里存 ARGB 整数而不是调色板
  下标** —— 下标会让以后调整顺序静默改掉所有人已经选过的颜色。只做一档不做浅色/深色两套：颜色是
  用户选出来的一个值，换主题时它应该还是同一个颜色。
- 删除清单的弹窗必须先把「里面的任务会怎样」说清楚（「里面的 N 条未完成任务不会被删掉，它们会回到
  未分类。」）。这是整个功能里唯一一处不可逆且影响别人的动作。删之前还会顺手清掉指向这条清单的筛选
  条件，否则删完是一个空列表，而原因在界面上看不出来。
- 标签的 `create` 是**补的**：原先只有任务编辑页输入时自动创建（`TaskRepository._ensureTag`）。管理页
  的 `create` 先按名字查一遍，命中就复用已有的那条，不让唯一索引抛异常 —— 异常要经过 drift 的类型再
  翻译成人话，链条太长，而且抛出来时调用方已经不知道该复用哪一条。
- 筛选面板是底部弹窗（`lib/features/home/widgets/task_filter_sheet.dart`），首页只留一行「活跃条件条」
  `_ActiveFilterBar`。清单 / 标签用的是 `ChoiceChip`（单选），优先级用 `FilterChip`（多选）。
- `TaskQuery` 新增 `hasFilters` 与 `filterCount`：空列表有两种空法——「本来就没有任务」和「条件把它们
  藏起来了」。这个判断此前在首页是手拼的四个条件，**漏了 `priorities`**；现在只有一份实现。
- `TaskQueryNotifier.clearFilters()` **不是** `reset()`：分段按钮选的是「看哪一批任务」，不是筛选条件。

**验收标准**

- [x] 任务的归属清单与多标签可增可删（编辑页可选清单、可加标签）
- [x] 删除清单时，其中任务不会丢失——有明确的处置选择（仓储上：删清单后任务 `listId` 置空而非被删；
  界面上：删除前弹窗说明「里面的 N 条未完成任务不会被删掉，它们会回到未分类。」。用例
  `test/features/organization_page_test.dart` 的 `删除前说清里面的任务会回到未分类，删完任务还在`）
- [x] 搜索在 1000 条任务下无明显卡顿（`test/data/search_benchmark_test.dart`：1000 条任务下四种搜索词
  全部 ≤ 1ms，含「命中 100 条」与「命中 0 条」两种极端。这是内存库 + 开发机的数字，抓的是量级错误，
  真机手感仍要上手试）
- [x] 筛选条件可组合，且能一键清空（清单 / 标签 / 优先级 / 逾期 / 完成状态可叠加；面板顶部、活跃条件条
  末尾、空态里各有一个「清空」入口。用例 `test/features/home_filter_test.dart` 6 条）
- [x] 排序与筛选状态在当前会话内保持（`lib/core/models/task_query.dart` 的 `TaskQueryNotifier`）

---

## M4 · 结构化任务

**状态**：已完成（2026-10-07）

> **校准说明**：子任务（新增 / 勾选 / 排序 / 删除 + 进度）与重复任务（编辑 / 生成下一条 /
> 作用范围）都已完整落地。
>
> **策略选择**：重复任务的完成策略是**生成下一条实例**，不是「推进同一条的截止日期」。
> 依据是本节的验收第 4 条——实例就是任务行，推进同一条的日期等于把「上个月我确实做过
> 这件事」这段历史抹掉。完整约定见 `docs/ARCHITECTURE.md` §5.3。

**交付物**

- 子任务：新增、勾选、排序（拖拽）、删除；父任务展示 `已完成/总数` 进度。
- 重复任务：每天 / 每周 / 每月 / 每年，间隔、指定周几 / 号数、结束条件（按次数或按日期）。
- `lib/core/recurrence/` 下的重复规则计算，纯函数、可单元测试。
- 任务完成后按规则生成下一次实例。

**实现说明**

- **系列锚点**：`recurrence_rules.startsOn` 存完整时刻（本地时间的 UTC 毫秒），整个系列的
  日期都由它递推，且**永远从锚点加整数倍**，不是从上一次结果再加一次。后者会把
  「31 日被夹到 28 日」的偏差累积下来，1/31 的系列过几个月就变成 28 号了。
- **夹到月末而不是溢出**：`addMonthsClamped` 让 1/31 → 2/28 → **3/31**（Dart 的
  `DateTime(2026, 2, 31)` 会溢出成 3/3）。
- **「仅此一次」与「此后全部」的唯一区别是锚点动不动**：只改这一条实例的日期时不动规则，
  下次生成时 `occurrenceOnOrBefore` 会把被挪走的实例吸回原节奏；选「此后全部」则把锚点
  挪到新日期。只有日期或重复设置真被改动过才会问这个，标题 / 备注的编辑不啰嗦。
- **`endCount` 只在 `nextAfterCompletion` 里判**：次数是「这个系列现在有几条任务」的函数，
  `occurrenceAfter` 拿不到这个数，所以它只管日期。判两处就会出现两个权威。
- **`setCompleted` 在一个事务里完成「标记完成 + 生成下一条」**，返回新任务 id，首页据此
  提示「下一条：YYYY-MM-DD」；重复勾选不会生成两条。
- **日期化的实例对齐节奏时取当天 23:59:59.999**：取 00:00 会让「锚点带时刻、实例只到日」
  的组合每次完成都生出同一天的下一条。
- **删除规则不删实例**：`tasks.recurrence_rule_id` 是 `ON DELETE SET NULL`，历史实例都还在，
  只是不再知道彼此属于一个系列——「结束重复」的语义是不再生成，不是抹掉过去。
- **规则锚点为 0 的老行**（v4 之前建的）读出来用 `createdAt` 兜底，不会算出 1970 年。

**验收标准**

- [x] 子任务全部勾选时父任务进度显示正确；父任务完成不强制子任务完成（反之亦然）（`subtaskDone` / `subtaskTotal` 计入领域模型）
- [x] 重复规则覆盖并测试以下边界：跨月、月末（1/31 → 2/28）、闰年、按周几、按次数结束、按日期结束
      —— `test/core/recurrence/recurrence_test.dart` 54 条 + `recurrence_text_test.dart` 16 条；
      另有一条属性用例断言「任何规则的前 200 次必须严格递增」。
- [x] 编辑重复任务时，可选择「仅此一次」或「此后全部」—— `_askScope()`，
      `test/features/task_editor_recurrence_test.dart` 里两个分支各有用例
      （锚点动不动是唯一区别，断言的就是这个）。
- [x] 结束重复不会删除历史已完成实例 —— 同上；测试连「规则行没了、任务还在」一起断言。
- [x] 重复规则计算有完整的单元测试（PRD 风险 9 点名项）—— 纯逻辑 70 条 + 仓储 16 条 +
      实例生成 18 条 + 编辑页 9 条。

---

## M5 · 本地提醒

**状态**：进行中（2026-10-07）· 代码已全部落地，仅剩真机送达验证

> **为什么提前**：专注计时（F 轨）依赖通知基础设施——「到点提醒」「强提醒」「锁屏进度」
> 全部落在这一节。它同时是任务提醒本身欠的债。**F 轨任何里程碑在 M5 完成前不得开工。**
>
> 2026-10-07 实现说明：`lib/main.dart` 现在按六步引导（建库 → 读偏好 → 初始化时区 →
> 初始化通知 → 拉起调度器 → 拉起时区监听）。剩余的最后一条验收需要真机在线，
> 用例已写好：`integration_test/reminder_delivery_test.dart`。

**交付物**

- `flutter_local_notifications` 初始化、Android 通知渠道、Android 13+ 通知权限请求流程。
- **前台服务 + 常驻通知**：计时进行中时在通知栏与锁屏显示已用 / 剩余时间，暂停时显示「已暂停」。
  Android 14+ 需声明 `FOREGROUND_SERVICE` 与 `FOREGROUND_SERVICE_SPECIAL_USE`，
  并在上架时填写 `specialUse` 子类型说明。
- **强提醒（可选开关）**：到点后重复响铃 + 振动，直到用户在通知里点「完成」或「稍后」。
- `timezone` + `flutter_timezone` 时区初始化与变更监听。
- 提醒调度器：把 `reminders.remind_at`（UTC 毫秒）转换为设备时区绝对时刻并调度。
- 设置项：提醒总开关、通知权限状态展示与引导。
- 时区变更后重新调度未过期提醒。

**验收标准**

- [ ] Android 真机/模拟器上能按时收到通知
      —— **用例已写（`integration_test/reminder_delivery_test.dart`），待设备连线后跑**。
      设备侧要先 `adb shell pm grant io.github.hesperyx.nowtodo android.permission.POST_NOTIFICATIONS`。
- [x] 权限被拒绝时应用完全可用，仅在设置页给出可关闭的提示
      —— 设置页「通知」区块同时展示两项权限现状并给出跳转引导，无阻断式弹窗。
- [x] 设备时区变更后，未过期提醒按新时区重新计算
      —— `TimeZoneWatcher` 在回到前台与 10 分钟轮询时检查，变了就 `scheduler.refresh()`；
      `test/core/notifications/timezone_watcher_test.dart` 8 条用例覆盖「变了 / 没变 /
      读不到 / 标识符不存在 / 回到前台 / dispose 后惰性」。
- [x] 删除任务时其提醒被一并取消
      —— 数据侧：`reminder_repository_test.dart`「任务被删掉时，它的提醒也一起没了」（走 `ON DELETE CASCADE`）；
      通知侧：调度器对同一批新数据先撤后排，任务消失后那条不再出现（`reminder_scheduler_test.dart`）。
- [x] Android 精确闹钟权限被拒时退化为非精确调度，且 UI 上有说明（不静默不响）
      —— `canScheduleExact()` 为假时改用 `inexactAllowWhileIdle` 而不是不排；
      设置页文案「提醒仍会响，但可能晚几分钟」。
- [x] 提醒时间换算逻辑有单元测试
      —— `test/core/notifications/reminder_plan_test.dart` 24 条 + `reminder_scheduler_test.dart` 15 条。
- [ ] 计时进行中，从最近任务列表划掉 App 后通知仍存活（前台服务未被系统回收）
      —— **移到 F6a**：它需要真实计时会话，属于专注页的验收。
- [x] Android 14+ 上前台服务类型声明正确，`specialUse` 子类型说明已填写
      —— `AndroidManifest.xml` 里 `foregroundServiceType="specialUse"` 与
      `android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 都已写入。
      上架表单里那栏仍留在 M8 的发布检查清单。
- [x] 强提醒在系统勿扰 / 静音模式下被压制时，UI 明确说明而不是静默失效
      —— 设置页「强提醒」副标题直接写明「系统的勿扰与静音仍会压制它——这不是应用能绕开的」。

---

## M6 · 外观与设置

**状态**：进行中（2026-10-07 校准）· 代码与机械校验已完成，仅剩真机肉眼走查

> **校准说明**：三档主题持久化、设置页、关于页（版本号 + MIT 全文弹窗 + 仓库 / 捐赠外链）
> 均已落地。深色模式的**可机械验证部分已做完**（见下面「深色模式走查」），
> 剩下的是真机上用眼睛看一遍——没有设备连线，暂时做不了。
> `lib/features/settings/settings_page.dart` 的策略是「只放真的会生效的开关」，
> 提醒与专注开关已随 M5 / F2 落地。

**交付物**

- 主题：浅色 / 深色 / 跟随系统，选择持久化；Material 3。✅
- 设置页：默认视图、主题、提醒开关、数据管理入口。⚠️ 前三项已落地；
  **数据管理入口（导入 / 导出）要等 M7**——放一个点不动的入口比不放更糟。
- 关于页：应用版本（`package_info_plus`）、MIT 许可证全文、开源仓库链接、捐赠入口。✅

**验收标准**

- [x] 三档主题切换即时生效并重启后保持
- [ ] 深色模式下无对比度不足或硬编码浅色导致的不可读文本
      —— **机械可验的部分已通过**（见下），真机肉眼走查待设备连线
- [x] 关于页正确展示版本号与 MIT 许可证
- [x] 捐赠入口为外链、完全自愿、不解锁任何功能
- [x] **恢复 iOS 时**：捐赠入口按 App Store 审核要求处理（必要时仅静态说明）。首版只发 Android，暂不涉及。

**深色模式走查**（2026-10-07）

能交给机器判断的都交了，剩下的明确留给眼睛：

1. **写死的颜色只剩 11 处**（`grep 'Colors\.[a-z]|Color\(0x' lib/`）：`entity_palette.dart` 的
   八个调色板色值、`onColor` 的黑白二选一、`app_theme.dart:18` 的种子色与一处
   `surfaceTintColor: Colors.transparent`。其余全部取自 `ColorScheme`。
2. **调色板重新配过**：原来那八个色值里有三个在深色卡片上对比度不足
   （墨绿 2.75、紫 2.96，下限是 3:1）。现在八个色值在**浅色与深色两种**卡片底上
   都达到 3.9:1，色块上的对勾 ≥4.3:1。改色值的约束写在
   `lib/core/theme/entity_palette.dart` 的文件头，改之前先跑测试。
3. `test/core/theme/contrast_test.dart`（13 条）：逐条量对比度——调色板、
   正文与次要文字、当文字用的强调色（逾期 = `error`、优先级 = `primary`/`tertiary`）、
   填充按钮上的文字都守 4.5:1；描边与圆点守 3:1。这条测试同时也守着「换种子色时别悄悄
   把某一档配色弄到看不清」。
4. `test/features/dark_mode_test.dart`（3 条）：让偏好真的落库成深色，然后把首页、
   新建页、编辑页、设置页、关于页、清单页、标签页、专注页**八个页面**都画一遍，
   断言不抛异常、拿到的确实是深色主题；另有一条断言首页卡片上的优先级、标签、日期
   都还在。

**仍然只能靠眼睛的部分**：真机上把三档主题各走一遍，看阴影 / 表面层级 / 对话框与
SnackBar 的观感、以及通知栏在那台机器的系统主题下长什么样。设备连线后与 M5 的
送达验证、F3 的进度显示一起做（见 §执行顺序第 6 条）。

---

## M7 · 导入导出

**状态**：已完成（2026-10-07）

> **校准说明**：格式（`docs/ARCHITECTURE.md` §9）此前只有骨架，`settings` 一段只列了三个键；
> 这次按真实表结构补齐成 12 项，并补上「合并 / 覆盖到底保留谁的」一节。
> **两个版本号是两件事**：`exportVersion` 管文件格式，`schemaVersion` 管库结构；
> 文件里两个都写，但决定「这份文件能不能读」的只有前者。

**交付物**

- JSON 全量导出（格式见 ARCHITECTURE §9）：写临时文件 → `share_plus` 分享 / 保存。
- JSON 导入：`file_picker` 选文件 → 整体校验 → 事务内落库。
- 导入模式：合并（按 `id`，保留较新的时间戳）/ 覆盖（清空后整份写入）。
- `exportVersion` 与数据库 `schemaVersion` 分离管理；高版本拒绝、低版本走升级函数链。
- 设置页新增「数据」区块：导出 / 导入两个入口，导入前先弹「怎么导入？」确认框
  （取消 / 合并导入 / 覆盖导入），覆盖那一步明确写着「先清掉现在的全部数据」。

**实现说明**

- **四层分工，每层都能单独测**：`lib/core/backup/backup_model.dart` 是纯数据（九张表的行类型
  ＋ `toMap()`，不依赖 Flutter 也不依赖 Drift）；`backup_codec.dart` 只管编解码与校验（纯函数，
  31 条单测）；`lib/data/backup/backup_file_service.dart` 只做平台 I/O（写临时文件 + 分享面板、
  选文件读文本），所以设置页的 7 条 widget 用例可以注一个假实现，不需要真的弹系统面板；
  `lib/data/repositories/backup_repository.dart` 才是落库。**若把编解码和文件选择揉在一起，
  这三样就都测不了了。**
- **校验一律在写库之前做完**：类型、枚举下标越界、同一张表内 id 重复、以及引用完整性
  （`tasks.listId` / `recurrenceRuleId`、`subtasks.taskId`、`reminders.taskId`、
  `taskTags` 的两头、`focusSessions.taskId`）。错误消息带路径，用户能自己定位：
  `data.tasks[3].listId 指向的清单（x）不在这个文件里。`
  引用完整性不查的后果是：`PRAGMA foreign_keys = ON` 会在写到第九张表时才炸，用户看到的是
  一句 SQLite 报错，而不是「第 4 条任务的清单不在文件里」。
  唯一的例外是**长度约束故意不查**——那是数据库的职责，撞上就整体回滚；
  半成功比失败更糟，所以宁可在最后一步全撤。
- **版本策略**：`exportVersion > kExportVersion` → 「这个文件来自更新的版本，先升级应用再导入」；
  `< kOldestExportVersion` → 「这个文件太旧」；中间的走 `_upgrade()` 的升级链
  （现在是空循环，结构先立着：等真加 v2 时补一个 `case`，不必在「拒绝所有老文件」和
  「到处写 if」之间选）。文件里的 `app.schemaVersion` 只是给人看的信息，不是门槛。
- **合并的取舍只看时间戳**：`_fileWins(本地, 文件) = 本地没有 || 文件严格更新`，**相等保留本地**
  ⇒ 同一份文件导入两次，第二次除设置外什么都不改（幂等）。各表的判据是
  清单 / 任务 `updatedAt`，标签 / 子任务 / 提醒 / 重复规则 `createdAt`，
  专注记录没有时间戳列、用 `startedAt`（一段会话的身份就是它什么时候开始的）。
- **标签按名字认亲**：`tags.name` 是唯一索引，本地已有同名标签（id 不同）时插新的会撞索引、
  整单回滚。所以先算出「文件标签 id → 本地标签 id」的映射，`taskTags` 跟着改指。
- **没结束的专注记录不搬**：`endedAt == null` 的行跳过。那是设备上的当前状态，
  搬过来会凭空多出一段「正在计时」，两条并存的会话还会让「当前会话」查询失去单值性。
- **设置是设备偏好，不是任务数据**：合并模式只在本地还是出厂值时接受文件里的设置
  （`AppPreferences.isDefault`，判 12 项、**不看 `initializedAt`**——那是第一次启动就会被写上的
  记账），否则整段跳过并计入「跳过了 1 项设置」；覆盖模式整份替换。
  导入别人的备份不该悄悄改掉我的主题和专注时长。
- **覆盖模式**先按反外键序清空八张表（`app_settings` 不动），全部写完再 `ensureInitialized()`：
  文件里没有内置收件箱时，应用也不会因此失去默认清单。
- **导入后不需要手动重排提醒**：`ReminderScheduler` 监听库里的流，写入自己会触发重算。
- **导出走 `appVersionProvider`**：`PackageInfo.fromPlatform()` 要过平台通道，
  页面里直接 `await` 会让这个页面在 widget 测试里永远 `pumpAndSettle` 不下去
  （通道没有对端，回复要真实事件循环）。把设备上下文挪进 provider 后，
  测试里换成一句固定版本号即可。

**验收标准**

- [x] 空库可正常导出（产出合法 JSON，不崩溃）—— `test/data/backup_repository_test.dart`
      「空库也能导出一份合法文件」＋ `backup_codec_test.dart`「空库也能编出合法 JSON 并读回来」。
- [x] 含清单 / 标签 / 子任务 / 提醒 / 重复规则的完整数据可导出并原样恢复 ——
      仓储用例「九张表都跟着出来」（逐表断言字段与枚举下标）与「导出再导入：data 段一模一样」
      （八张表的数组 + `settings` 整段深比较）。
- [x] 损坏 JSON、缺字段、`exportVersion` 过高 —— 均给出可读错误且**不写入任何数据** ——
      codec 20 条（根与版本 7 条、字段 13 条，都是断言消息里的那句话说到了什么）
      ＋ `test/features/settings_backup_test.dart`「文件读不出来：给出人话，库一点没动」。
- [x] 导入为单事务，中途失败后数据库保持导入前状态 —— 仓储用例
      「写到一半撞上库的约束：数据库保持导入前的样子」，故意喂一条**标题是空串**的任务，
      让 `withLength(1, 500)` 生成的 CHECK 在 SQLite 层拦下来。
- [x] 导出文件可被第三方工具解析（格式公开）—— 两空格缩进、驼峰键、枚举写下标；
      codec 用例「缩进过的人话，第三方工具能直接看」。
- [x] 导入导出有覆盖上述场景的单元测试 —— 31（codec）＋ 16（仓储）＋ 7（设置页）＝ **54 条**；
      全量 `flutter test --concurrency 1` 615 条全绿。

**仍然只能靠眼睛的部分**：真机上导出后分享面板长什么样、用系统文件选择器挑 `.json` 的手感、
以及从「最近任务」切走再回来时文件选择器会不会被回收。与其余真机项一起做（见 §执行顺序）。

---

## M8 · 发布准备

**状态**：已完成（2026-10-08）；四条需要设备或控制台的验收挂在下面「只能靠真机的部分」

**交付物**

- 集成测试：冷启动 → 创建任务 → 加标签 → 设提醒 → 完成 → 导出 的端到端流程。
- 隐私政策文档（明确不采集任务内容、不强制联网、不默认追踪）。
- 应用图标与启动图。
- Android 签名配置、`applicationId` 最终确认。（iOS 签名与 `bundle id` 随 iOS 恢复时再做。）
- 商店文案、截图、分类与内容分级信息。
- 发布检查清单（见下），前五项由 `tool/release_check.ps1` 一条命令跑完。

**验收标准**

- [ ] 集成测试在真实 Android 设备上通过 —— **用例已就位**（`integration_test/end_to_end_test.dart`
      两条：界面全流程一条、导出文件往返一条），执行要等设备连线（`adb devices` 当前为空）
- [x] 隐私政策可公开访问，内容与应用实际行为一致 —— `docs/PRIVACY.md`，托管在公开仓库里即可访问；
      「没有联网权限」这句由打包产物与测试双重保证（见下）
- [x] `applicationId` 已确认为最终值（**上架后不可更改**）—— `io.github.hesperyx.nowtodo`
- [x] 应用图标在 Android 自适应图标各尺寸下显示正常 —— 五档密度 + 传统 / 前景 / 单色三层齐全，
      `test/android/app_icon_test.dart` 16 条盯着尺寸、颜色类型、三层声明与安全圆（含逐像素检查）；
      真机启动器里的观感见「只能靠真机的部分」
- [x] 首版不含网络权限申请 —— `aapt dump badging` 在 release APK 上实测：权限只有
      `POST_NOTIFICATIONS`、`RECEIVE_BOOT_COMPLETED`、`SCHEDULE_EXACT_ALARM`、`FOREGROUND_SERVICE`、
      `FOREGROUND_SERVICE_SPECIAL_USE`、`VIBRATE` 与自动生成的 `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
- [x] 崩溃 / ANR / 数据丢失问题清零或已记录已知限制 —— 首版刻意不接任何崩溃上报 SDK（那与隐私承诺冲突），
      所以「清零」的形态是：已知限制写进 `CHANGELOG.md`「已知约束」（无云同步、无悬浮窗、界面仅中文、
      工具链版本锁定）＋ `docs/PRIVACY.md` 说明数据边界；真机走查项列在检查清单里
- [x] 1.0.0 条目已写入 `CHANGELOG.md` —— 按 任务 / 提醒 / 专注计时 / 统计与成就 / 数据 / 外观与平台 分组

### 实现说明

- **`applicationId` 与 `namespace` 一起改成 `io.github.hesperyx.nowtodo`**，选它是因为它绑在不会过期的
  GitHub 账号上；Kotlin 源码目录同步搬到 `android/app/src/main/kotlin/io/github/hesperyx/nowtodo/`。
  清单里的 `.MainActivity` / `.FocusWidgetProvider` 是相对类名，跟着 `namespace` 解析，所以清单没动。
  **踩坑**：Kotlin DSL 构建脚本里直接写 `java.util.Properties()` 会被解析成 Gradle 的 `java` 扩展
  （`Unresolved reference: util`），必须在文件最顶上 `import java.util.Properties`。
- **签名配置**：`signingConfigs.create("release")` 读仓库根的 `android/key.properties`；
  文件不存在时退回 debug 签名——能构建、不能上架，两种情况下命令都是同一条。
  模板与 `keytool` 步骤写在 `android/key.properties.example`，密钥文件已由 `.gitignore` 挡住。
- **图标是脚本生成的**，不是手绘：`tool/app_icon/generate_icons.py` 画「开口朝上的环 + 环内的勾」
  （环 = 专注计时，勾 = 做完了），产物提交进仓库，脚本自己量安全区（前景层最远像素半径
  `0.2803` 画布，上限 `33/108 = 0.3056`），超了直接报错退出。商店特色图片同理，
  `tool/app_icon/generate_store_assets.py` 复用同一套品牌色常量，横向按内容整体居中。
- **启动图**：`values/colors.xml` 与 `values-night/colors.xml` 各给一个 `launch_background`，
  `drawable/launch_background.xml` 用「品牌色 + 居中前景层」；Android 12+ 另有
  `values-v31` 与 `values-night-v31` 两份 `styles.xml`。**必须是两份**：资源限定符里版本号排最后，
  `values-night` 会盖掉 `values-v31`，只写一个的话深色用户拿不到 `windowSplashScreenBackground`。
- **端到端集成测试跑的是真实启动路径**：给 `main()` 加了一个 `{List<Override> overrides}` 的缝，
  用例只把「碰系统 UI 的部件」换掉（分享面板在自动化里点不到），其余真库、真通知、真时区。
  其中一条刻意绕开界面的时间选择器，从仓储写一条提醒、再问系统要 `pendingNotificationRequests()`，
  因为要证明的是「提醒进库 → 系统里真的多了个闹钟」，而系统对话框里拨表盘既脆又没有信息量。
- **`tool/release_check.ps1`**：把检查清单前五项机械化的脚本。第一步是**重跑代码生成再确认
  工作区没变化**（`*.g.dart` 提交入库，改了 Drift 表定义却忘了重跑 `build_runner` 时，
  生成物会和源码对不上，而本地 `analyze`、`test` 都不会响——`RecurrenceRules.startsOn` 的
  文档注释就是这么漏过一次的，靠这条门抓回来）。`dart format` 用的是 **Flutter 自带**的 SDK（本机 PATH 上的独立 dart
  是 3.11.5，与 Flutter 3.35.5 自带的 3.9.2 不是同一个格式化器，版本不一致时这道门会变成假信号）。
  `-Apk` 会额外打一次 release 包并用 `aapt` 核对包名、应用名与「不许出现 `INTERNET`」。
  **这道 codegen 门只看 `lib/` 与 `test/`**：`pubspec.lock` 里 116 行 `url:` 记的是依赖从哪个 host
  拉下来，开发机走 `pub.flutter-io.cn` 镜像、CI 走 `pub.dev`，两边会互相改写这些行——依赖版本由
  lock 钉着、并没有真的变化，判整棵工作区只会让这道门在「生成产物其实没问题」的时候变红，
  报错信息还会把人往 `build_runner` 上引。CI 上就是这么红过一次，最后靠让失败步骤自己打印
  `git status --porcelain` 才定位到是 `pubspec.lock`。
- **商店资料**写在 `docs/STORE.md`：商店里能填的每一项（名称、简短说明、完整说明、更新说明、
  分类、标签、内容分级问卷、数据安全表单）都先写成可直接粘贴的底稿，另附八张截图的拍摄清单
  与 `adb` 命令——截图只能出自真机，模板里不占位假图。

### 发布检查清单

前五项一条命令：`powershell -File tool/release_check.ps1 -Apk`

- [x] `dart run build_runner build` 后工作区无变化（生成产物与源码同步）
- [x] `dart format --set-exit-if-changed .` 通过（用 Flutter 自带的 dart）
- [x] `flutter analyze` 零告警
- [x] `flutter test` 全绿
- [x] 数据库迁移测试覆盖所有历史 `schemaVersion`（v1→v4、v2→v4、v3→v4 与全新安装共 8 条）
- [x] CI 在 Linux 上跑通同一套门（格式 / 分析 / 测试 / Android debug 构建）—— `main` 上 `1155473`
      与 `d1d08aa` 两个 job 全绿（run #4 / #5）；开发机是 Windows、CI 是 ubuntu，这一步顺带补上了
      开发机看不见的平台差异（原生 sqlite 库的来源就不同：Windows 退回 `winsqlite3.dll`，
      Linux 用 `libsqlite3.so.0`）
- [ ] 在**全新安装**与**从上一版本升级**两种路径下均手工走查核心流程（首版只需走全新安装）
- [ ] 在真机上验证：断网可用、通知按时、时区切换后提醒正确
- [ ] 导出 → 卸载 → 重装 → 导入，数据完整恢复

### 只能靠真机的部分

- 端到端集成测试的两条用例：`flutter test integration_test/end_to_end_test.dart -d <deviceId>`
  （先手动授予通知权限，见文件头注释）。
- 图标与启动图在真机启动器里各遮罩形状下的观感（机械部分已由像素级检查覆盖）。
- 全新安装走查、断网 / 通知 / 时区三项、导出 → 卸载 → 重装 → 导入。
- `docs/STORE.md` §5 的八张截图。截图必须出自真机，模板里不放占位图。

---

## 专注计时（F 轨）

> 2026-10-07 起，专注计时（番茄钟）与待办并列成为核心子系统，裁决见 `docs/PRD.md` 末尾
> 「范围变更记录」。编号独立于 M 轨，因为两者要交错推进。
>
> **硬前置：M5 未完成前，F 轨任何里程碑不得开工。**
> **全局约束：计时精度在切后台、锁屏、进程被杀三种情况下都不能丢。**

### F1 · 计时内核（纯 Dart，可单测）

**状态**：已完成（2026-10-07）

**交付物**

- `lib/core/focus/focus_timer.dart`：`FocusTimerState` 不可变值对象
  （`startedAt` / `pausedMillis` / `pausedAt` / `plannedSeconds` / `mode` / `kind`）
  \+ 纯函数 `elapsed(now)` / `remaining(now)` / `isFinished(now)` / `progress(now)`
  \+ `pause(now)` / `resume(now)` / `copyWith(...)`。
- `lib/core/focus/focus_stats.dart`：`logicalDateFor(startedAt, midnightMode, midnightEndHour)`
  与按日 / 按小时分桶的纯聚合函数。
- **硬约束：计时不用 `Timer` 累加。** 状态对象里没有任何计时器字段，UI 层用
  `Stream.periodic` 每秒以 `DateTime.now()` 做差值重算。
  理由：`Timer` 在后台与锁屏会被系统压制，累加值必然漂移；进程被杀后累加状态直接归零，
  而时间戳差值可以随时从数据库恢复。

**实现说明**

- 枚举 `FocusSessionKind { focus, shortBreak, longBreak }` 与
  `FocusTimerMode { countUp, countDown }` 追加进 `lib/core/models/enums.dart`
  （`intEnum` 存的是下标，只能往后追加），中文名在 `lib/core/models/enum_labels.dart`。
- 倒计时的计划时长可以为空：`FocusTimerState.started()` 不给 `plan` 时落到
  `FocusTimerState.defaultPlan`（25 分钟）。裸构造仍然要求倒计时必须给 `plan`，
  断言拦的是「自己拼一个没有终点的倒计时」。正计时给了 `plan` 也会被断言拦住。
- `copyWith` 的 `null` 是「不改」而不是「置空」，所以清空 `pausedAt` 走的是
  `clearPausedAt: true` 这个显式开关。`resume()` 必须用它——这一点有专门注释，
  因为写成 `pausedAt: null` 会静默地什么都不做。
- `secondsByHourOfDay` 会把跨小时的会话**切开**分别落进真正占据的小时。把 23:30
  开始的 90 分钟整块算给 23 点，会让「我几点最坐得住」这张图给出相反结论。
- `logicalDateFor` 回退一天用的是 `DateTime(y, m, d - 1)` 而不是
  `subtract(Duration(days: 1))`：夏令时那天的长度不是 24 小时，减固定时长会偏。

**验收标准**

- [x] `elapsed()` 只依赖传入的 `now`：同一状态对象在不同时刻调用单调递增，无任何可变计时字段
      —— `test/core/focus/focus_timer_test.dart`（`elapsed` 组 + `构造约束` 组）；
      `FocusTimerState` 是 `const` 构造 + 全 `final` 字段。
- [x] 多次暂停 / 恢复后累计时长正确
      —— 同一文件 `暂停与恢复` 组 6 条，含四段暂停的累计（10+20+10 分钟）与
      「恢复时刻早于暂停时刻不让累计变负」。
- [x] 午夜模式：0–4 点开始归前一天；`03:59:59` 与 `04:00:00` 两个边界各有用例
      —— `test/core/focus/focus_stats_test.dart` `logicalDateFor · 午夜模式（边界 4 点）` 组 7 条，
      另含跨月、跨年与可配置边界小时。
- [x] 全部为纯函数单测，无平台依赖，`flutter test` 直接跑
      —— 两个文件都不 import Flutter，`test/core/focus/` 下 61 条用例；全量 196 条全绿。

### F2 · 专注记录落库（schemaVersion 3）

**状态**：已完成（2026-10-07）

**交付物**

- 新表 `focus_sessions`：`id` / `taskId`（可空，FK→`tasks`，**`onDelete: setNull`** ——
  删任务不该抹掉已专注的历史）/ `startedAt` / `endedAt`（可空 = 进行中）/ `pausedMillis` /
  `pausedAt` / `plannedSeconds` / `actualSeconds` / `kind` / `timerMode` / `logicalDate` /
  `completed` / `note`。索引三条：`logical_date`、`task_id`、`started_at`。
  > 实现时比原清单多出两列：
  > `pausedAt` —— 只有 `pausedMillis` 的话，用户在暂停状态下被系统杀进程，重开后
  > 只能看到「从开始就一直跑着」，整段暂停会被安静地算成专注时间，而杀进程恰恰
  > 是这套设计必须扛住的场景；
  > `note` —— F3 的「记一笔」要求会话结束后能写备注，原清单里没有地方放。
  > 两者都趁 v3 尚未发布时一并加上，不需要为它们单独开一次迁移。
- `tasks` 加列 `estimatedPomodoros`（可空：「没估过」与「估了 0 个」不同）。
- `app_settings` 加专注相关列（专注 / 短休 / 长休时长、几轮后长休、自动接续、默认计时模式、
  午夜模式及边界小时）。新增列一律 `withDefault`，不需要写数据迁移。
- `schemaVersion 2 → 3` 的 `onUpgrade`；**重导 `drift_schemas/drift_schema_v3.json`**；
  重新 `drift_dev schema generate`；`test/data/migration_test.dart` 增加 v1→v3 与 v2→v3 用例。
  > v1 → v2 已由强提醒占用（`app_settings.strongReminders`），迁移机制已跑通一次，
  > 加版本的完整五步见 `docs/ARCHITECTURE.md` §6.1。
  > **新建表必须自己补 `createIndex`**：`m.createTable(...)` 不会顺手建
  > `@TableIndex` 声明的索引，只有 `createAll()` 会。漏掉不报错，靠
  > `migrateAndValidate` 比对索引才兜得住。
- `FocusSessionRepository`：`start` / `pause` / `resume` / `finish` / `cancel` /
  `unfinished()`（进程被杀后恢复用）/ 按 `logicalDate` 区间的聚合查询。

**实现说明**

- 时间算术只写一遍：仓储的 `pause` / `resume` / `finish` 都把行还原成
  `FocusTimerState`（`TodoFocusSession.toTimerState()`）再交给计时内核，
  不另写一套毫秒加减。
- 不变式「最多一条 `endedAt IS NULL`」由 `start()` 在同一个事务里
  **先收掉旧会话**（停在新的开始时刻、按内核补算时长）来维持，而不是报错拒绝——
  调用方可能是崩溃恢复之后的重开，那条僵尸会话在语义上已被取代。
  收尾时补算而不是写 0：被取代的那一段是真实发生过的时间。
- 正在跑的那条 `actual_seconds` 还是 0，统计要用
  `TodoFocusSession.elapsedSeconds(now)` 现算（`slicesBetween` 已接好），
  否则界面上今天永远是 0，直到用户点结束才突然跳上来。

**验收标准**

- [x] 从 v1 库升级到 v3 后，已有任务 / 清单 / 设置数据一条不丢
      —— `test/data/migration_test.dart` 的 `v1 升到 v3 不丢数据，新表与新增的设置列取到默认值`
      在 v1 连接上用裸 SQL 写进任务 / 清单 / 设置再升上来逐字段断言（生成的
      `schema_vN.dart` 里没有 Companion，造老数据只能走 `customStatement`）。
- [x] `drift_schemas/drift_schema_v3.json` 已签入，`migration_test.dart` 的 v1→v3 与 v2→v3 用例都通过
      —— 当时六条用例覆盖 v1→v3、v2→v3 两条路径，外加「全新安装结构与快照一致」
      「v2 升到 v3 时用户自己调过的设置不丢」「三条索引都建出来了」。
      **后续（M4 把版本推到 v4）同一个文件长到 8 条，这两条路径改名成 v1→v4 / v2→v4，
      断言一条没动**——迁移测试的语义是「任意历史版本都能升到最新」，不是「升到 3 为止」。
- [x] 杀进程后重开，`unfinished()` 能取回进行中的会话，`elapsed()` 与崩溃前连续
      —— `test/data/focus_session_repository_test.dart` 的 `崩溃恢复` 组两条，
      含「崩溃前正暂停着，重开后依然冻在那一刻」。
- [x] 任意时刻最多只有一条 `endedAt IS NULL` 的会话（有测试）
      —— `不变式：最多一条未结束` 组三条，覆盖「旧会话已走满」与「旧会话正暂停着」
      两种收尾形态。注意这条不变式只能靠仓储 + 用例守：SQLite 的部分唯一索引
      `@TableIndex` 表达不了，而在 `beforeOpen` 里裸建会被 `migrateAndValidate`
      判成快照外的多余索引。
- [x] 删除任务后其历史会话保留且 `taskId` 置空（有测试）
      —— 同文件 `归属任务能带上，任务被删之后会话历史保留、taskId 置空`。


### F3 · 专注页与会话生命周期

**状态**：已完成（2026-10-07）· 代码与测试全部落地，第 1、2 条验收待真机复核

**交付物**

- 路由 `/focus`，可从首页进入；任务详情页提供带 `taskId` 的「开始专注」入口。
  地址形如 `/focus?task=<id>`：`/focus` 本身就是一条完整地址，用查询参数比
  多一段路径更贴合「可有可无的归属」这件事。
- 时长设置：专注 5–180 分钟、休息可调；高于 / 低于边界时拒绝并提示。
  边界与文案收在 `lib/core/focus/focus_settings.dart`（纯 Dart，无 Flutter 依赖），
  `validateMinutes` 直接返回给用户看的那句话，而不是 bool —— 调用点拿到 bool
  之后还得再写一遍同样的分支去编一句话，那种重复很快会出现「提示和规则不一致」。
- 正计时 / 倒计时切换；开始 / 暂停 / 恢复 / 放弃 / 完成 的完整状态机与 UI。
- App 重启后自动发现未结束会话并提示恢复：首页顶部一条 `_ResumeBanner`，
  AppBar 上的计时器图标带 `Badge`。
- 会话结束后「记一笔」：挂到任务（可换）、可选备注。
- **超出原清单的产物**：`lib/core/notifications/focus_notification_sync.dart`
  —— 常驻通知与「到点兜底提醒」的同步器。

**实现说明**

- **界面不持有时间**：`FocusPage` 的 `Timer.periodic(1s)` 只做
  `setState(() => _now = DateTime.now())`，所有数字都由
  `runningSessionProvider` 那条记录加上 `_now` 现算。计时内核早就保证
  「时长 = 时间戳之差」，ticker 再多存一份「已过多久」就是第二份随时会漂的真相。
  空闲时不建这个定时器：否则这一页会在没人看的地方每秒重建一次
  `SegmentedButton` 组成的整个表单。
- 常驻通知的进度交给系统渲染（正计时给 `chronometerStart`，倒计时给
  `countdown`），应用一秒改一次通知文本是不行的：进程被系统压制时数字就停住了，
  用户看到的是一个安静地卡住的计时器。
- 到点兜底提醒会随「暂停 / 恢复」重排（暂停时直接撤掉）：留一条旧的在系统里，
  就会出现「已经暂停了却还是响了」，恢复时终点又要往后挪。
- 会话跑满的判定有 `_finishHandled` 与 `_busy` 双重守卫：ticker 每秒都可能
  撞上同一个「已经走满」的状态，而收尾是一次写库加一次弹层。
- **收尾弹层重读库里那份**（`FocusSessionRepository.findById`）：调用方手里
  的对象是开始那一刻的快照，`actualSeconds` 还是 0、`completed` 还是 false，
  直接拿去渲染就是对着刚专注了 25 分钟的人说「这一段记下了 / 实际 00:00」。
- `_prefs` 读不到流时退到 `initialPreferencesProvider`（启动时真读过库的那份），
  而不是 `const AppPreferences()`：默认值只是「没读到」，用它顶替会让
  `_start()` 拿默认时长开工、让 `_completeCountdown()` 按 `autoStartNext == false`
  停下 —— 全发生在用户看不见的地方。
- 「今天第几轮专注」由 `listBetween(今天, 今天)` 现数，不落库：
  统计口径只有一份，重启后也不会与历史累计对不上。

**验收标准**

- [ ] 切后台 5 分钟后回前台，显示时长与真实经过时间误差 < 1s
      —— **机制已由测试覆盖，秒表级复核待真机**：
      `test/features/focus_page_test.dart` 的 `倒计时走满` 组把会话的开始时刻
      设到 26 分钟之前（内存里什么都没有，库里那条按时间戳算已经走满），
      重开后界面在第一次 tick 就判出走满并按 25 分钟记账；显示值同理不来自
      帧计数。真机复核方式与 M5 最后一条相同，需要设备在线。
- [ ] 锁屏状态下计时不漂移，通知里的进度同步
      —— **通知侧已实现、待真机确认**：锁屏与通知栏上的数字是系统按
      `chronometerStart` / `countdown` 自己走的，不依赖应用进程；
      `test/core/notifications/focus_notification_sync_test.dart` 15 条覆盖
      「挂哪个字段、暂停时撤到点提醒、恢复时终点从此刻重算」。
      漂移本身由时间戳推导保证，与第 1 条同源。
- [x] 杀进程后重开，未结束会话被恢复且时长连续
      —— `test/data/focus_session_repository_test.dart` 的 `崩溃恢复` 组两条
      （含「崩溃前正暂停着，重开后依然冻在那一刻」），
      以及 `test/widget_test.dart` 的 `库里留着未结束的会话时，首页顶部给出恢复入口`
      —— 从首页点「返回」能直接回到正在进行的那一段。
- [x] 倒计时走满触发休息提示 / 自动接续（依设置）
      —— `test/features/focus_page_test.dart` 的 `倒计时走满` 组两条：
      关自动接续时弹「记一笔」且写明是**走满**（`completed == true`，文案
      「这一段走满了」而不是「这一段记下了」）；开自动接续时按
      `breakAfterFocus` 直接接一段 5 分钟短休息，不弹层。
      休息时长与轮次规则的边界在 `test/core/focus/focus_settings_test.dart` 15 条里。
- [x] 正计时模式不判「未完成」，只记录实际时长
      —— `test/data/focus_session_repository_test.dart` 的
      `正计时结束永远不算完成`；界面上正计时态改为说明文案
      「正计时不限时，想停的时候自己点结束。它不会被算成「没完成」。」
      正计时不给计划时长这件事由 `start()` 的断言守着（带上 plan 会被拦住）。

### F4 · 统计与热力图

**状态**：已完成（2026-10-07）

**校准说明**：交付物第二条写的「自绘（`CustomPainter` 或 `GridView`）」实际用的是
第三种做法：`LayoutBuilder` 算格子边长 + `Row` 手排。理由是这一格要能点、要带
`Semantics` 和 `Tooltip` —— `CustomPainter` 画的是一片像素，点选要自己算坐标、
无障碍要自己写；而 `GridView` 在「一个月 7 列」和「一年 12 块、每块又是 7 列」
这两种结构下还要额外处理主滚动冲突。代价是格子数就是 widget 数（一年 365 个），
低端机上滚动手感需要真机看一眼（与 F3 进度显示一起做）。

**交付物**

- 统计页 `lib/features/focus/stats_page.dart`：概览（总时长 / 次数 / 有记录天数）、
  连续天数（现在与最长）、高效时段（24 小时分桶 + 峰值）、时长分布（日 7 / 周 12 /
  月 12 三档切换）、专注日历（月视图 + 年视图）。入口：专注页标题栏的「统计」图标、
  首页「更多」菜单里的「专注统计」；路由 `AppRoutes.stats = '/stats'`。
- 热力图 `lib/features/focus/widgets/heatmap.dart`：五档（无记录 / 来过没计时 /
  < 15 分钟 / 15–60 分钟 / ≥ 1 小时）各自配色 + 图例，`FocusMonthHeatmap` 与
  `FocusYearHeatmap`；点一格弹出那一天的完整说法。
- 全部统计只读 `focus_sessions`，按 `logicalDate` 分组；**不新增汇总表**
  （读路径就是 F2 的 `FocusSessionRepository.slicesBetween`）。
- 聚合纯函数 `lib/core/focus/focus_stats.dart`：F2 已有的 `FocusSlice` /
  `logicalDateFor` / `secondsByDay` / `secondsByHourOfDay` / `currentStreakDays` /
  `longestStreakDays`，加上 F4 的 `FocusDaySummary` / `summarizeDays` /
  `fillDayRange` / `weekStartOf` / `monthStartOf` / `groupBySpan` / `peakHour` /
  `heatOf` / `FocusStats`。
- 统计口径的文案格式化 `formatDurationText` / `formatSecondsText` 落在
  `lib/core/utils/time.dart`，与计时器用的 `formatDuration`（`25:00`）分开。

**验收标准**

- [x] 一年 365 天的聚合在本机 < 100ms —— `test/data/focus_stats_benchmark_test.dart`：
  365 天、每天 3 段（1095 条）实测**读库 3ms / 聚合 20ms**，断言取三次里最慢的一次
  `< 100ms`（读库另给 `< 1000ms` 的宽线，只用来抓「365 次查询」这种量级错误）。
- [x] 热力图对「无数据的日期」与「有数据但为 0」区分显示 —— `FocusHeat.none` 与
  `.zero` 是两档：前者 `surfaceContainerHighest` + 描边、后者 `primary` 低透明度，
  说法分别是「没有专注记录」「有 N 次记录，但没计时」。
  证据：`test/core/focus/focus_stats_test.dart` 的 `heatOf · 五个档位`（6 条，含负秒数
  归 zero）、`test/features/stats_page_test.dart` 的「有记录但一秒没计时，仍然算有数据」
  与「热力图把「有记录没计时」和「没有记录」分开说」。
- [x] 0 条会话时给出空态，而不是画一张全 0 的图 —— `_StatsEmpty` 不画热力图、不画柱子，
  只给「还没有专注记录」+ 一个「去专注」按钮。证据：`test/features/stats_page_test.dart`
  第一条（顺带断言此时 `FocusMonthHeatmap` / `FocusYearHeatmap` 都不存在）。
- [x] 聚合函数为纯函数，可脱离数据库单测 —— `lib/core/focus/focus_stats.dart` 不 import
  Flutter，只吃 `FocusSlice` / `FocusDaySummary`；`test/core/focus/focus_stats_test.dart`
  64 条全部不碰数据库（同一个文件里 `logicalDateFor` 等 45 条是 F2 时写的）。

**实现说明**

1. **窗口固定 365 天、一次读进来**（`kFocusStatsWindowDays`）：翻月份、切年视图都只在
   内存里重排，不再查库。代价是超过一年的旧记录不进图——统计页的口径就是「最近一年」，
   页面上把起止日期写出来了。
2. **不落汇总表**：`FocusStats` 是一次算好的快照对象，由 `focusStatsProvider` 提供。
   汇总表要么每次写入都要同步、要么会跟会话数据对不上，而 1095 段聚合只要 20ms。
3. **`focusStatsProvider` 必须是 `autoDispose`**：离开统计页后监听者归零，快照跟着丢掉，
   下次打开重新读。没有它的话「刚结束一段专注再打开统计页」看到的还是应用启动那次算的
   数字，而且永远不会自己变。（也试过在 `initState` 里主动 `ref.invalidate`，会在
   `dependOnInheritedWidgetOfExactType` 上抛「called before initState completed」。）
4. **热力图的阈值写死**（15 分钟 / 1 小时），不按当批数据算分位：分位数每看一次都可能变，
   图例就写不住，跨周也没法比。
5. **`secondsByDay` 丢掉 0 秒的日子、`summarizeDays` 保留**：前者是「哪几天有时长」
   （连续天数用它），后者是「哪几天有记录」（热力图用它）。两个口径混用会把「来过但
   没计时」的一天算进连续天数。
6. **跨小时的会话按整点切开**（F2 就写好的 `secondsByHourOfDay`）：23:30 开始的 90 分钟
   是 30 分钟给 23 点、60 分钟给 0 点。全算给 23 点会把「几点最坐得住」这个结论弄反。
7. **小时桶是整个窗口里的同一个钟点**，不是「每天 9 点那一段」的平均值——一年里每天
   9 点那 25 分钟会累加到同一格。
8. **月视图只允许翻完整落在窗口内的月份**（`canBack` / `canForward` 都由窗口边界算出来），
   所以热力图永远不会画出「窗口外」这第六种格子状态。
9. **已结束的会话用库里存的时长**（`slicesBetween` 直接用 `actualSeconds`），不按
   `startedAt` 重算——统计口径必须和当时记下来的那一笔一致；只有还没结束的那条才用
   `now` 补实时时长。
10. **数字只往上取整到分钟**：`formatSecondsText` 直接丢秒（25 分 59 秒写「25 分钟」），
    不四舍五入——统计页的每个数字都是「至少这么多」。

### F5 · 成就徽章

**状态**：已完成（2026-10-07）

**交付物**

- `lib/core/focus/achievements.dart`：徽章定义（key / 标题 / 描述 / 达成判定纯函数）。
- **不落表**：解锁状态由会话记录实时推导。理由：解锁状态本就是派生值，存一份必然与
  会话数据不一致；落表还要额外回答「改了判定规则后已解锁的怎么办」。
- 徽章页：已解锁 / 未解锁两态 + 进度提示。

上面三条原样落地，落点如下：

- `lib/core/focus/achievements.dart`：`AchievementUnit`（次 / 天 / 小时 / 分钟）、
  `AchievementFacts`（一次算好的派生值：累计时长、条数、有记录天数、当前与最长连续、
  最忙的一天、最长的一段、早起与夜猫子条数）、`Achievement`（key / title / description /
  unit / target / valueOf）、`const kAchievements` 14 枚、`AchievementProgress`
  （`unlocked` / `ratio` / `remaining` / `progressText`）、`evaluateAchievements`、
  `unlockedCount`、`AchievementBoard`（事实 + 进度，页面要靠事实分辨「一条记录都没有」）。
  14 枚按从易到难排：第一步、满一小时、连续三天、早起鸟、夜猫子、十段、满十小时、
  一天四段、连续一周、长跑（单段 90 分钟）、深度一天（单日 180 分钟）、一百段、
  满一百小时、连续一个月。
- 徽章页 `lib/features/focus/achievements_page.dart`：头部是「已解锁 N / 14」+ 一条总进度条，
  下面 14 行按从易到难排；解锁的行只有奖杯图标，未解锁的行多一条进度条与「还差 N 单位」。
  一条记录都没有时给空态（「还没有专注记录」+「去专注」），读不出来时给重试。
- 入口两处：专注页标题栏的「徽章」图标、首页「更多」菜单里的「成就徽章」；
  路由 `AppRoutes.achievements = '/achievements'`（`lib/app/router.dart`）。
- 数据入口 `achievementsProvider`（`lib/app/providers.dart`，`autoDispose`）：
  用 F2 的 `FocusSessionRepository.slicesBetween(from: 0, to: today)` 读**全部历史**
  （不截一年），交给 `AchievementFacts.from` 与 `evaluateAchievements`。

**验收标准**

- [x] 判定为纯函数，给定会话列表即可复现（有单测）—— `achievements.dart` 不 import Flutter、
  不碰数据库，只吃 `FocusSlice`；`test/core/focus/achievements_test.dart` **27 条**全部不碰
  数据库，其中「同一批记录重算两次结果一样」与「只有『现在几点』会变结果，历史长短
  不随今天漂」两条正面钉住「纯」。
- [x] 新会话写入后徽章状态即时更新，不需要全表以外的额外索引 —— `test/features/`
  `achievements_page_test.dart` 的「新记录写进去之后，重新进徽章页就是新的数字」：
  空态 → 写一段 25 分钟 → 回到页面就是「已解锁 1 / 14」。即时性由
  `achievementsProvider` 的 `autoDispose` 保证（离开页面监听者归零、下次进来重算），
  没有缓存也没有失效通知。查询只有 `slicesBetween` 这一条，走 `focus_sessions` 已有的
  `logicalDate` / `startedAt` 索引，**F5 没有加任何索引、没有加任何表**。
- [x] 仓库中不存在「解锁记录」表；修改判定规则后历史状态可重算 ——
  `test/features/achievements_page_test.dart` 最后一条直接问 sqlite：
  `SELECT name FROM sqlite_master WHERE type = 'table'` 过滤掉 `sqlite_` 开头之后，
  正好是那九张表，且没有一张名字里带 `achievement`。可重算：判定只吃
  `AchievementFacts`，规则表 `kAchievements` 是编译期常量，改一行规则就是下次进页面
  重新 `evaluateAchievements` 的结果——历史记录一个字都不用动。

**实现说明**

1. **判定形状统一成「一个计数器 + 一个目标」**：`Achievement` 只带
   `target` 与 `int Function(AchievementFacts) valueOf`，解锁态、进度条、还差多少
   全由这两个值推出来。加一枚徽章是加一行常量，不是加一段页面代码。
2. **派生值一次算好**（`AchievementFacts`）：14 枚徽章各扫一遍记录就是 14 遍 O(n)；
   现在一遍。这也是它做成「一个装好的对象」而不是一组顶层函数的原因。
3. **徽章看全部历史，不跟统计页一样截 365 天**：「累计 100 小时」算的是一辈子的账。
   代价是解锁「一百小时」之后每次进徽章页都要扫全部记录——这条记录量级下可接受。
4. **0 秒记录的口径分两类**：数条数的徽章（`sessions_*`、`day_four`）把它算进去，
   因为一条 0 秒记录是「用户确实启动过计时器」的证据（统计页的「来过没计时」同理）；
   求时长的徽章（`hours_*`、`deep_day`、`marathon`）只看秒数。连带把「第一步」的描述
   写成「启动第一段专注」——它确实能被一段 0 秒的记录解锁。
5. **`value` 照实保留，只有 `ratio` 封顶**：解锁之后 `progressText` 仍显示真实累计
   （「累计 3 小时 20 分」比「3 小时」诚实），进度条由 `ratio` 收在 1。
6. **不落表的代价写在明面上**：每次进页面都要重算。换掉的是一张必然与记录不一致、
   而且改了规则就要回答「已解锁的还算不算」的表。
7. **`achievementsProvider` 必须 `autoDispose`**：理由同统计页——刚结束一段专注再进来，
   看到的要是新的数字。
8. **页面拿的是 `AchievementBoard` 而不是进度列表**：进度列表永远是 14 条，
   分辨不出「一条记录都没有」；把事实对象一起带出来，页面不用猜。

### F6 · 平台能力（可拆，按性价比排序）

**状态**：F6a 与 F6b 已落地（2026-10-07），F6c 未做（可选项）

- **F6a 常驻通知进度**：依赖 M5 的前台服务。锁屏可见，零特殊权限，最稳。
- **F6b 桌面小组件**：Android App Widget，展示今天专注了多久 + 最近七天的柱状条。
- **F6c 悬浮窗**（可选）：`SYSTEM_ALERT_WINDOW` 是跳系统设置页手动授权的特殊权限，
  各厂商 ROM 行为不一。先做未授权时的引导页（**未开始**）。

**交付物**

F6a：

- `lib/core/notifications/flutter_notification_service.dart` 的 `showOngoing`：
  `visibility: NotificationVisibility.public`，让锁屏上看得见进度（原本系统默认的
  `private` 会在「隐藏敏感内容」开启时把正文抹成占位文字）。
- 沿用 M5 的内容：`NotificationService.showOngoing()` / `stopOngoing()`（走
  `AndroidServiceForegroundType.foregroundServiceTypeSpecialUse`）、
  `lib/core/notifications/focus_notification_sync.dart`（会话状态 → 通知的串行同步）、
  manifest 里的 `ForegroundService`（`android:stopWithTask="false"`、
  `foregroundServiceType="specialUse"`、`PROPERTY_SPECIAL_USE_FGS_SUBTYPE`）。
- 机械防线 `test/android/focus_foreground_service_test.dart`（7 条）：直接读
  `AndroidManifest.xml` 与 `flutter_notification_service.dart` 两份文本，断言五个权限、
  「没有 `INTERNET`」、服务的三处关键属性与代码里传的类型一致、
  「锁屏可见 + 划不掉」、两个广播接收器与重启过滤器都在。
  这些漏一条的症状全是静默失效（通知不出现、划掉 App 后消失、Android 14+ 抛
  `SecurityException`），静态断言比等真机复现便宜。

F6b：

- `lib/core/widget/home_widget_snapshot.dart`（纯 Dart）：`kHomeWidgetDays = 7`、
  `homeWidgetWindowStart(int today)`、`HomeWidgetSnapshot`（`today` / `seconds` /
  `sessions` / `week` / `levels` / `headline` / `caption` / `toMap()` /
  `fromSlices(..., today:)`）。
- `lib/core/widget/home_widget_service.dart`：`HomeWidgetService` 接口 +
  `NoopHomeWidgetService` + `MethodChannelHomeWidgetService`（通道
  `now_todo/widget`，方法 `update`，非 Android 直接返回，`MissingPluginException`
  静默吞掉）、`buildWidgetPayload()`（快照 + 深浅两套配色）。
- `lib/core/widget/home_widget_sync.dart`：`HomeWidgetSync`，启动推一次 +
  每次会话变化推一次，串行队列。
- `lib/core/theme/heat_colors.dart`：`focusHeatColor` / `onFocusHeatColor` /
  `kFocusHeatOrder` / `focusHeatPalette`，从 `lib/features/focus/widgets/heatmap.dart`
  搬来共用（`features/` 不能被 `core/` 依赖，而小组件与热力图必须同一套档位）。
- `lib/app/providers.dart`：`homeWidgetServiceProvider`、`homeWidgetSyncProvider`；
  `lib/main.dart` 第 7 步读一次把同步挂上。
- Android 侧：`FocusWidgetProvider.kt`（`AppWidgetProvider`，读 SharedPreferences
  画 `RemoteViews`，过期时换成「还没更新今天的记录」）、`HomeWidgetBridge.kt`
  （`MethodChannel` 写入 + 触发重画）、`MainActivity.kt` 里 `register`、
  manifest 里的 `.FocusWidgetProvider` receiver（`exported="false"`）、四份资源
  （`values/strings.xml`、`layout/focus_widget.xml`、`values/styles.xml` 的
  `FocusWidgetBar`、`xml/focus_widget_info.xml`）。
- 测试三个文件：`test/core/widget/home_widget_snapshot_test.dart`（窗口边界、标题与
  文案、四档阈值、`toMap` 键名）、`test/core/widget/home_widget_service_test.dart`
  （真发一次快照、非 Android 不发、两种异常都不炸、两套配色的来源）、
  `test/android/home_widget_test.dart`（清单声明、`R.id` 与布局 id 交叉核对、
  **Dart 发过去的每个键 Kotlin 侧都读了**、通道名两边一致、同一份 SharedPreferences）。

**验收标准**

- [ ] F6a：通知栏与锁屏均显示实时进度，暂停时显示「已暂停」
      —— 代码齐（`visibility: public` + 系统渲染的计时器），**待真机复核**。
- [ ] F6a：从最近任务列表划掉 App 后常驻通知仍存活（前台服务未被系统回收）
      —— 从 M5 移来。M5 已交付 `NotificationService.showOngoing()` 与 manifest 里的
      `specialUse` 声明，这里要验的是它真的扛得住系统回收，**待真机复核**。
- [ ] F6b：小组件在系统刷新周期内刷新（进程被杀后仍显示上次数据）
      —— 机制已落地（快照存平台侧 SharedPreferences，`updatePeriodMillis="1800000"`
      到点由系统重画上次那份），**待真机复核**。
- [ ] F6c：未授权时给出系统设置跳转引导，授权后悬浮窗可拖动、可关闭（未做，可选项）
- [x] 未授予上述任一权限时，专注计时的核心功能**仍然完全可用**
      —— 小组件通道失败只 `debugPrint`（`MissingPluginException` 静默），
      通知权限被拒时 `FocusNotificationSync` 整条链路是 no-op；
      计时本身是数据库里的 `startedAt` + `pausedMillis`，与两者无耦合。

**实现说明**

1. **F6b 不引 `home_widget`，自写通道**：理由是少一个依赖、少一套要跟着调的默认样式；
   而「进程被杀后仍显示上次数据」本来就要求数据落在平台侧（SharedPreferences），
   插件并不能省掉这一步。代价是四份资源 + 两个 Kotlin 文件要自己维护。
2. **小组件不查库**：桌面那块卡片画的是一份推过去的快照。应用在跑时顺手推，
   应用不在时由系统的刷新周期重画上次那份。让 Kotlin 侧读 sqlite 会把数据库
   格式、迁移、加锁全搬到平台层，那是另一套要跟着 drift 一起升级的东西。
3. **两套配色一起发，由 Kotlin 按系统 `uiMode` 挑**：小组件的深浅色跟的是系统夜间模式，
   不是应用里那份设置——用户在系统里切模式时应用可能压根没在跑。
4. **过期判断用 `today` 与当天比对，不拿昨天的数字冒充今天**：日期对不上就换成
   「还没更新今天的记录 / 打开应用刷新」。30 分钟的系统刷新下限本来也不够用来
   做「每分钟更新」，它只负责跨零点后换文案。
5. **触发点只有两个，不开定时器**：启动一次 + 会话变化一次，理由同通知同步
   ——「每秒改一次通知」那种做法在小组件上更糟（RemoteViews 每帧都要过一遍 IPC）。
6. **串行队列**：一段专注结束会连着来几个状态变更，交错写会让最后落在桌面上的那份是旧的。
7. **`none` 档在小组件里用 `outlineVariant` 填**：RemoteViews 画不了描边，
   热力图的「空格子」在这里只能是一块浅灰。
8. **配色公式搬到 `lib/core/theme/heat_colors.dart`**：热力图与小组件必须同一套档位，
   两处各写一份公式的话，改一处就总有一处没改。
9. **Kotlin 侧八个配色键名显式写成常量**（不拼 `"surface$suffix"`）：
   `test/android/home_widget_test.dart` 拿 Dart 发过去的键名去比对这边的字面量，
   拼出来的名字咬不住这类漂移。
10. **`test/android/` 这类测试每台机器都能跑**：它们读的是仓库里的文本文件，
     `flutter test` 的工作目录就是包根。平台侧声明漏一条的症状全是静默失效，
    静态断言比「等真机复现」便宜得多。

---

## 执行顺序

依赖驱动的推荐顺序。**不要并行铺开** —— PRD 点名的头号风险就是范围蔓延。

**进度（2026-10-08）**：1 的代码全部落地（只剩真机送达验证）、3 已跑完（F1 / F2 / F3 均已完成，
F3 第 1、2 条验收待真机复核）、M0–M4 与 M6 已收尾、4 里的 F4 与 F5 也已完成、5 的 F6a 与 F6b
也已落地（F6c 未做，可选）、6 里的 M7 与 **M8 都已完成**（发布准备：端到端集成测试、隐私政策、
图标与启动图、正式签名配置与 `applicationId`、商店资料、CHANGELOG 与发布检查脚本）。
**1.0.0 的功能范围到此为止，剩下的全是真机项**：M6 肉眼走查、F4 滚动手感、M5 送达验证、
F3 进度显示、F6a 常驻通知、F6b 小组件、M7 分享面板与文件选择器手感、M8 的集成测试与发布清单
里那三条手工走查，都卡在设备连线上（`adb devices` 当前为空）。

1. **M5 · 本地提醒**（已提为最高优先级）。F 轨的硬前置，也是任务提醒本身欠的债。
2. **M2 / M3 / M4 / M6 的收尾缺口**（均为 1.0.0 必须）：
   - M3 ✅ 已完成：清单与标签管理页、可组合筛选面板（详见 M3 一节）。
   - M4 ✅ 已完成：重复规则编辑 UI + `lib/core/recurrence/` 纯函数 + 边界单测（详见 M4 一节）。
   - M6：深色模式人工走查
   - 两处「界面在撒谎」都已修掉：
     `lib/features/task_editor/task_editor_page.dart` 对新任务承诺「保存之后可以添加子任务与**提醒**」
     —— 提醒这一半已随 M5 修掉（编辑页现在真的有提醒区块）；
     `lib/features/about/about_page.dart` 承诺「导出再导入」—— M7 已补齐，
     文案改成指路「在『设置 → 数据』里导出再导入就行」。
3. **F1 → F2 → F3**：计时内核 → 落库 → 页面。内核与落库先于 UI，因为 UI 只是它们的显示层。
4. **F4 → F5**：统计 → 徽章。两者都只读 F2 的数据，可各自独立验收。
   - F4 ✅ 已完成：统计页（概览 / 连续天数 / 高效时段 / 日周月分布 / 月年热力图）+
     `lib/core/focus/focus_stats.dart` 纯函数（详见 F4 一节）。
   - F5 ✅ 已完成：徽章页（14 枚，两态 + 进度）+ `lib/core/focus/achievements.dart`
     纯函数；不落表，解锁状态每次现算（详见 F5 一节）。
5. **F6**：平台能力，按 a → b → c 的性价比顺序。
   - F6a ✅ 已落地：锁屏可见的常驻通知（`visibility: public`）+ `test/android/`
     的静态防线（详见 F6 一节）。真机验收待设备连线。
   - F6b ✅ 已落地：桌面小组件（`lib/core/widget/` 三个 Dart 文件 +
     `FocusWidgetProvider.kt` / `HomeWidgetBridge.kt` 与四份资源），
     不引 `home_widget`，快照存平台侧 SharedPreferences（详见 F6 一节）。
   - F6c 未做：可选，见 F6 一节。
6. **M7 → M8**：导入导出与发布准备。
   - M7 ✅ 已完成：`lib/core/backup/`（模型 + 编解码与校验）、`lib/data/backup/`（平台 I/O）、
     `BackupRepository`（单事务落库、合并 / 覆盖两种模式）、设置页「数据」区块；
     54 条单测（详见 M7 一节）。导出格式覆盖 `focus_sessions`，
     `exportVersion 1` 与 `schemaVersion 4` 各管各的（字段清单见 `docs/ARCHITECTURE.md` §9）。
   - M8 ✅ 已完成：端到端集成测试（`integration_test/end_to_end_test.dart`）、`docs/PRIVACY.md`、
     图标与启动图（`tool/app_icon/`）、正式签名配置与 `applicationId`（`io.github.hesperyx.nowtodo`）、
     `docs/STORE.md`、`CHANGELOG.md` 的 1.0.0 条目、`tool/release_check.ps1`（详见 M8 一节）。
     真机项列在 M8「只能靠真机的部分」。

---

## 增强项（1.0.0 之后）

以下内容不在首版里程碑内。启动任一项之前需先更新 PRD 并开 Issue 讨论范围。

| 项 | 备注 |
| --- | --- |
| 桌面小组件 | 已定级为 **F6b**（见上文）。依赖原生 App Widget 实现，成本较高 |
| 日历视图 | 月视图聚合，需要新的查询与缓存策略 |
| 多语言 | 文案迁入 `l10n/`，先做 zh-Hans / en |
| 无障碍优化 | 语义标签、TalkBack 走查、动态字体 |
| 主题色自定义 | Material 3 动态取色 + 手动色板 |
| 手势操作 | 滑动完成 / 删除 / 顺延（滑动删除已实现，其余待做） |
| 快速添加 | 主屏快捷方式、分享目标接入 |
| CSV 导出 | 复用 M7 的导出层，加一个序列化器 |
| **PDF 导出** | **暂缓**。需引 `pdf` + `printing`（含原生代码），且 `pdf` 默认字体无中文，要内嵌中文字体子集，包体积 +5~10 MB。想分享给非技术用户，用「导出统计图为图片」更划算、零依赖 |
| **「待办集」第三层容器** | **暂缓**。用「父任务 + 子任务」表达「写论文」这类项目即可，`subtasks` 表成本为零。新增 `task_groups` 会让清单 / 标签 / 待办集三层交叉，筛选、排序、拖拽、导入导出全部各加一层 |
| 可选匿名崩溃统计 | **默认关闭**，首次启动询问，绝不采集任务内容 |
