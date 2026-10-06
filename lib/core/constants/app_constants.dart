/// 全应用共享的常量。
///
/// 集中在这里是为了让「这个数字是什么意思」永远只有一个答案。
abstract final class AppConstants {
  /// 应用显示名。
  static const String appName = 'Now Todo';

  /// SQLite 数据库文件名（不含扩展名）。
  ///
  /// **改这个名字等于换一个数据库**：用户会看到所有任务「消失」。
  /// 它只是为了内部可读性，不是产品名，产品名变了也不要跟着改。
  static const String databaseName = 'now_todo';

  /// 内置「收件箱」清单的固定 id。
  ///
  /// 刻意用一个可读的 slug 而不是 UUID：一眼能看出它是内置行，
  /// 而且导入别人的备份时，两边会合并到同一个清单而不是各建一个。
  static const String inboxListId = 'builtin-inbox';

  /// 导入导出格式版本。
  ///
  /// 只有在格式发生**破坏性**变更时才提升，并且必须同时提供
  /// 「旧版本文件仍可导入」的兼容路径。见 `docs/ARCHITECTURE.md` §8。
  static const int exportVersion = 1;

  /// 导出文件名前缀。实际文件名会带日期，如 `now-todo-backup-2026-10-08.json`。
  static const String exportFilePrefix = 'now-todo-backup';

  /// 源码仓库地址。
  ///
  /// 同一份地址在 `.github/ISSUE_TEMPLATE/config.yml` 里还硬编码了 4 处
  /// （discussions / PRD / CONTRIBUTING / SECURITY 的跳转链接），
  /// 那是 YAML，改仓库地址时容易漏。
  /// （`SECURITY.md` 本身不含 URL：漏洞报告走 GitHub 的私有安全公告通道。）
  static const String repositoryUrl = 'https://github.com/Hesperyx/Now-Todo';

  /// 捐赠入口。留空字符串表示「不展示捐赠按钮」。
  ///
  /// 锚点必须和 README.md 里 `## 捐赠` 这一节的标题逐字对应（GitHub 按标题文本
  /// 生成锚点），改标题就要同步改这里，否则按钮会落到仓库首页顶部而不是捐赠说明。
  ///
  /// 捐赠完全自愿，不解锁任何功能。iOS 上不展示外链按钮：App Store
  /// 审核对应用内的外部支付链接有额外要求，关于页改为纯文字说明。
  static const String donationUrl = 'https://github.com/Hesperyx/Now-Todo#捐赠';
}
