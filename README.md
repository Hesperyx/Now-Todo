# Now Todo

**开源、离线优先的个人待办应用。** 面向 Android，基于 Flutter 构建。

无账号、无广告、无付费墙、无云端上传。数据默认只存在你的设备上，随时可导出成文件自行备份。

[English](#english) · [产品需求文档](docs/PRD.md) · [架构设计](docs/ARCHITECTURE.md) · [里程碑](docs/MILESTONES.md) · [隐私政策](docs/PRIVACY.md) · [商店资料](docs/STORE.md)

---

## 为什么做这个

市面上的待办应用普遍存在几个问题：功能被项目管理和协作能力撑得臃肿；基础提醒、标签、主题被塞进订阅付费墙；任务内容属于敏感数据，却被迫上传云端；网络不好时连新增一条任务都做不到；导出能力弱，数据迁移困难。

Now Todo 的取舍很明确——**只做个人任务管理，把这件事做完整**。

## 核心特性（首版范围）

- **任务管理**：新增、编辑、删除、完成、恢复；标题、备注、截止日期（可到分钟）、优先级。
- **视图**：今日、全部、已完成、按清单浏览。
- **组织**：清单分类、多标签、搜索、排序、筛选、一键清空已完成。
- **结构化**：子任务拆分与进度展示、重复任务（每天 / 每周 / 每月 / 每年，可设间隔与结束条件）。
  改一条重复任务时会问「仅此一次」还是「此后全部」。
- **提醒**：本地通知，精确闹钟，按设备时区调度，重启与时区变更后自动重排，不依赖网络。
- **专注计时**：正计时 / 倒计时、番茄钟节奏、暂停与恢复、挂到任务上、通知栏常驻进度
  （锁屏可见，划掉应用也不中断）。
- **统计与成就**：时长与连续天数、24 小时分布、按月 / 按年热力图、成就徽章——全部本地计算。
- **外观**：浅色 / 深色 / 跟随系统，自适应应用图标与启动图。
- **数据**：本地离线数据库；JSON 全量导入导出（可合并或覆盖），格式版本与库结构版本分开管理。
- **桌面小组件**：今日专注时长与热力图快照。
- **关于页**：MIT 许可证展示、自愿捐赠入口。

### 路线图（增强项，按迭代推进）

日历视图 · 多语言 · 无障碍优化 · 主题色自定义 · 手势操作 · 快速添加 · CSV 导出 · 悬浮窗进度 · 可选匿名崩溃统计（默认关闭）

### 明确不做

账号体系 · 云同步 · 多设备同步 · 多人协作 · 团队空间 · 付费墙 · 广告

## 技术栈

| 领域 | 选型 |
| --- | --- |
| 框架 | Flutter stable（Dart 3.9+） |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 本地数据库 | SQLite（`sqlite3_flutter_libs`）+ Drift |
| 通知 | `flutter_local_notifications` + `timezone` / `flutter_timezone` |
| 文件读写 | `file_picker` · `share_plus` · `path_provider` |
| 测试 | `flutter_test` · `mocktail` · `integration_test` |

选型理由写在 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 开发环境

要求：Flutter stable（本项目在 **Flutter 3.35.5 / Dart 3.9.2** 上验证）、Android SDK（构建 Android）、Visual Studio 2022（构建 Windows 桌面预览）。

```bash
flutter --version
flutter doctor
```

```bash
git clone https://github.com/Hesperyx/Now-Todo.git
cd Now-Todo
flutter pub get
flutter run -d windows     # 桌面快速预览
flutter run -d android     # 需要已授权的 Android SDK
```

### 常用命令

```bash
flutter analyze                                  # 静态分析
dart format --output=none --set-exit-if-changed . # 格式检查
flutter test                                     # 单元 / Widget 测试
dart run build_runner build                       # 重新生成 Drift 数据库代码
powershell -File tool/release_check.ps1 -Apk      # 发布前检查（格式 + 分析 + 测试 + 产物权限）
```

格式检查请用 **Flutter 自带**的 `dart`（`<flutter>/bin/cache/dart-sdk/bin/dart.exe`）。
如果 PATH 上还装了独立安装的 Dart SDK，它的版本与 Flutter 自带的通常不一样，
两个格式化器的输出不保证一致——按一个版本排好的代码可能在另一个版本下「需要改动」。
`tool/release_check.ps1` 已经固定用 Flutter 自带的那一份。

代码生成产物（`*.g.dart`）已提交入库，克隆后即可直接 `flutter run`。修改了 Drift 表定义后，必须重跑 `build_runner`。（本项目不使用 Riverpod 代码生成，provider 一律手写，原因见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#已知约束)。）

## 项目结构

```
lib/
├── main.dart                 # 入口：初始化时区 / 通知 / 数据库
├── app/                      # App 外壳、主题、路由
├── core/                     # 通用工具、常量、结果类型、扩展
├── data/
│   ├── database/             # Drift 表定义与 DAO
│   ├── models/               # 领域模型与序列化
│   └── repositories/         # 仓储实现
├── features/                 # 按功能切分的 UI + 状态
└── l10n/                     # 本地化资源（增强项阶段启用）
docs/                         # PRD、架构、里程碑
test/                         # 单元测试与 Widget 测试
.github/                      # CI 与 Issue/PR 模板
```

## 贡献

欢迎 Issue 与 PR。开始之前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

提交 PR 前请确保：

```bash
dart format .
flutter analyze
flutter test
```

## 数据与隐私

完整说明见 [docs/PRIVACY.md](docs/PRIVACY.md)。要点：

- 不需要账号。发布版 APK **不申请 `INTERNET` 权限**——不是「承诺不上传」，是系统层面
  就不允许建立网络连接（`test/android/focus_foreground_service_test.dart` 有用例盯着这一点）。
- 不采集任务内容，无广告、无追踪、无第三方分析 SDK、不读取设备标识。
- 数据只存在本机应用私有目录，卸载应用会一并删除。
- 唯一的出境路径是「设置 → 数据 → 导出」：由你主动触发，文件去哪由系统的分享面板决定。
- 换机或刷机前请先导出备份——这是目前唯一的备份手段。

## 许可证

[MIT](LICENSE)。可自由使用、修改、分发，需保留版权与许可声明。

## 捐赠

项目免费且完整，捐赠完全自愿，**不解锁任何功能**。捐赠入口见应用内「关于」页。

---

<p align="center">If Now Todo saves you time, a star helps others find it.</p>
