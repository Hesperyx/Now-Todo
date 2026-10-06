# 更新日志

本文件记录 Now Todo 的所有重要变更。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

分类说明：`新增` / `变更` / `弃用` / `移除` / `修复` / `安全`。

---

## [未发布]

项目初始化。首版（1.0.0）尚未发布，以下内容随开发推进持续追加。

### 新增

- 建立 Flutter 项目骨架，目标平台 Android，另保留 Windows 桌面用于本地开发预览。
  iOS 暂不在目标平台内（首版只发 Android），`ios/` 目录与 `cupertino_icons` 依赖已移除。
  参见 `docs/PRD.md` 末尾的「范围变更记录」。
- 落盘产品需求文档 `docs/PRD.md`，作为范围裁决的唯一事实来源。
- 建立仓库治理文件：MIT 许可证、README、贡献指南、行为准则、更新日志。
- 接入核心依赖：Riverpod（状态管理）、go_router（路由）、Drift + SQLite（本地数据库）、
  `flutter_local_notifications` + timezone（本地提醒）、`file_picker` / `share_plus` / `path_provider`（导入导出）。
- 建立 GitHub Actions 持续集成：格式检查、静态分析、单元测试、Android 构建。
- 建立 Issue 与 PR 模板。

### 已知约束

- 当前开发工具链为 Flutter 3.35.5 / Dart 3.9.2。该 SDK 版本下 `drift_dev`（Drift 代码生成器）
  与 `flutter_riverpod` 3.x 无法共存，详见 `docs/ARCHITECTURE.md`。依赖版本因此被显式锁定。

---

## 版本规划

| 版本 | 主题 | 状态 |
| --- | --- | --- |
| 1.0.0 | 首版 MVP：任务、清单、标签、优先级、截止日期、提醒、子任务、重复任务、搜索、深色模式、导入导出 | 开发中 |

增强项（桌面小组件、日历视图、统计面板、多语言、无障碍等）在 1.0.0 之后按迭代推进，
详见 `docs/MILESTONES.md`。
