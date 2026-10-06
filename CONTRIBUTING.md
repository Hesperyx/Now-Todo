# 贡献指南

感谢你愿意为 Now Todo 花时间。本文档说明如何搭建环境、写代码、跑检查、提 PR。

参与本项目即表示你同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

---

## 目录

- [开始之前](#开始之前)
- [开发环境](#开发环境)
- [项目结构](#项目结构)
- [代码规范](#代码规范)
- [代码生成](#代码生成)
- [数据库迁移](#数据库迁移)
- [测试](#测试)
- [提交信息](#提交信息)
- [分支与 PR 流程](#分支与-pr-流程)
- [Issue 规范](#issue-规范)
- [设计约束](#设计约束)

---

## 开始之前

先读 [docs/PRD.md](docs/PRD.md)。它是产品范围的唯一事实来源——**功能取舍以 PRD 为准**，不在这里的功能就是不在首版范围内。

再看 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，了解技术选型与分层约定。

如果你要做的改动超出 PRD 的「首版核心范围」，请先开 Issue 讨论，不要直接写 PR。

## 开发环境

| 工具 | 版本要求 |
| --- | --- |
| Flutter | stable，本项目在 3.35.5 上验证 |
| Dart | 随 Flutter 附带，要求 `^3.9.2` |
| Android SDK | 任意可编译 Android 8.0+ 的版本 |
| Visual Studio 2022 | 仅构建 Windows 桌面预览需要 |

```bash
flutter --version
flutter doctor          # 全部勾选后再动手
flutter pub get
flutter run -d windows  # 桌面是最快的调试目标
```

> 若 `flutter doctor` 报 Android licenses 未接受，运行 `flutter doctor --android-licenses`。

## 项目结构

```
lib/
├── main.dart              # 入口：初始化时区、通知、数据库，然后 runApp
├── app/                   # MaterialApp 外壳、主题、go_router 路由表
├── core/                  # 与业务无关的工具：常量、扩展、格式化、结果类型
├── data/
│   ├── database/          # Drift 表定义、AppDatabase、DAO
│   ├── models/            # 领域模型、枚举、JSON 序列化
│   └── repositories/      # 仓储：对上层屏蔽数据来源
├── features/              # 按功能切分，每个功能自带 UI + provider
│   ├── tasks/
│   ├── lists/
│   ├── tags/
│   ├── search/
│   └── settings/
└── l10n/                  # 本地化资源（增强项阶段启用）
```

**分层规则**：UI 只依赖 provider / repository，不直接 import Drift 生成的代码；`data/` 不依赖 `features/`。跨层引用一律通过 `data/repositories/`。

## 代码规范

提交前必须全部通过：

```bash
dart format .
flutter analyze
flutter test
```

- 静态分析规则见根目录 `analysis_options.yaml`，启用了 `strict-casts` / `strict-inference` / `strict-raw-types`。**不要为了绕过告警而加 `// ignore`**——先判断是代码问题还是规则误报，是规则问题就在 PR 里说明并调整配置。
- 不做 `as dynamic`、不做 `!` 强行解包来掩盖可空性。可空性是真问题，不是噪音。
- 注释解释「为什么」，不解释「是什么」。`// 把 id 赋值给 id` 这种注释不要写。
- 面向用户的文案不要硬编码在 Widget 里，集中放在 `core/constants/` 或后续的 `l10n/` 下。
- Widget 拆到 200 行以内；超过就拆子 Widget 或抽 `part` 文件。

## 代码生成

Drift 的数据库代码由 `build_runner` 生成，产物（`*.g.dart`）**提交入库**，这样克隆后可以直接 `flutter run`。

修改了以下内容后必须重新生成：

- `lib/data/database/` 下的表定义
- 任何带 `@DriftDatabase` / `@DriftAccessor` 注解的类

```bash
dart run build_runner build
```

（`build` 子命令本身就会清理冲突的旧产物，不需要再加 `--delete-conflicting-outputs`；该参数已在 `build_runner` 2.15 中移除，加上只会多一条警告。）

CI 会校验生成产物与源一致，忘记重跑会导致 CI 失败。

**注意**：本项目不使用 Riverpod 代码生成。原因是 `riverpod_lint` 与 `drift_dev` 在当前 Flutter/Dart SDK 上存在 analyzer 版本冲突（详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#已知约束)）。Riverpod 一律手写 provider。

## 数据库迁移

数据是用户资产，迁移必须谨慎。

- 每次修改表结构，必须同时提升 `schemaVersion` 并写 `MigrationStrategy`。
- 迁移测试放在 `test/data/database/migration_test.dart`，用 Drift 的 `schema` 导出做逐步验证。
- 禁止使用 `onUpgrade` 里直接 `deleteTable` 或重建库的做法——那是数据丢失。
- 新版本必须能读取上一个版本的数据库文件；改了字段类型或语义要在 PR 描述里明确写出。
- 导出格式的版本号（`exportVersion`）与数据库 `schemaVersion` 是**两套独立版本**，导入时要分别处理。

## 测试

| 类型 | 位置 | 要求 |
| --- | --- | --- |
| 单元测试 | `test/` | 仓储、重复规则计算、导入导出、日期工具必须有 |
| Widget 测试 | `test/features/` | 新增页面至少覆盖空态与主流程 |
| 迁移测试 | `test/data/database/` | 每次改表结构必须补 |

- 新增纯逻辑代码（尤其是重复任务规则、提醒时间计算、JSON 导入校验）时，**测试是 PR 的一部分**，不是可选项。
- 修 Bug 的 PR 请先写一个能复现的失败测试，再修。
- 用 `mocktail` 做替身；不要为了测试方便给生产代码加 `@visibleForTesting` 以外的东西。

```bash
flutter test                          # 全量
flutter test test/data/               # 指定目录
flutter test --coverage               # 覆盖率
```

## 提交信息

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>
```

`type` 取值：`feat` `fix` `refactor` `perf` `test` `docs` `build` `ci` `chore` `revert`

`scope` 建议：`tasks` `lists` `tags` `search` `notifications` `settings` `db` `backup` `theme`

示例：

```
feat(tasks): 支持按优先级排序
fix(notifications): 修正跨时区提醒时间偏移
docs(prd): 明确首版不含云同步
```

- 主题行用中文或英文均可，但**同一个 PR 内保持一致**。
- 一次提交只做一件事。格式化产生的全文件 diff 请单独成一个 `style:` 提交。

## 分支与 PR 流程

1. 从 `main` 切分支：`feat/xxx`、`fix/xxx`、`docs/xxx`。
2. 小步提交，保持每次提交可编译。
3. 推送前跑完 `dart format . && flutter analyze && flutter test`。
4. 开 PR，填写模板，关联 Issue（`Closes #123`）。
5. CI 全绿 + 至少一位维护者 review 后合并，采用 **Squash and merge**。

PR 描述请写清楚：**改了什么、为什么这么改、怎么验证的、有没有已知副作用**。涉及 UI 的改动请附截图或录屏。

## Issue 规范

- 用提供的模板（Bug 报告 / 功能请求）。
- Bug 报告请附：应用版本、系统版本、复现步骤、期望结果、实际结果、必要日志。
- **不要在 Issue 里粘贴真实的任务内容、备份文件或任何个人数据**。定位问题只需要描述和脱敏日志。
- 功能请求请先对照 PRD，说明它属于首版范围还是增强项。

## 设计约束

这些是项目的底线，PR 违反会被直接拒绝：

1. **离线优先**：任何核心功能（增删改查、提醒、搜索）都不得依赖网络。
2. **不引入账号体系**：不做登录、注册、云同步、多设备同步。
3. **不引入商业追踪**：不加广告 SDK、不加默认开启的分析 SDK、不加付费墙。
4. **不采集任务内容**：任何日志、崩溃上报、统计都不得包含用户任务文本。
5. **不锁定数据**：导出格式必须公开、有版本号、可被第三方解析。任何导致用户数据无法完整导出的改动都要在 PR 里显式说明理由。
6. **不新增不必要的权限**：新权限必须在 PR 里论证必要性，并在 README 的隐私章节同步说明。

## 许可证

本项目使用 MIT 许可证。提交 PR 即表示你同意你的贡献以 MIT 许可证发布。引入第三方代码或资源时，必须确认其许可证与 MIT 兼容，并在 PR 中注明来源与许可证。
