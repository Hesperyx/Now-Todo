import 'enums.dart';
import 'task_query.dart';

/// 枚举的中文显示名。
///
/// 单独放一个文件，是为了让「枚举值」和「它怎么显示」分开：
/// `enums.dart` 里的声明顺序是**落库的值**（`intEnum` 存的是 index），
/// 每加一个显示名都不该让人担心会不会动到数据库。
///
/// 这一层刻意不依赖 Flutter —— 将来接 `l10n` 时，这里就是唯一的替换点。
extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.none => '无',
    TaskPriority.low => '低',
    TaskPriority.medium => '中',
    TaskPriority.high => '高',
  };
}

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
    TaskStatus.pending => '未完成',
    TaskStatus.completed => '已完成',
  };
}

extension TaskSortLabel on TaskSort {
  String get label => switch (this) {
    TaskSort.dueDate => '截止日期',
    TaskSort.priority => '优先级',
    TaskSort.createdAt => '创建时间',
    TaskSort.title => '标题',
  };
}

extension DefaultViewLabel on DefaultView {
  String get label => switch (this) {
    DefaultView.today => '今天',
    DefaultView.all => '全部',
    DefaultView.completed => '已完成',
  };
}

extension ReminderRepeatTypeLabel on ReminderRepeatType {
  String get label => switch (this) {
    ReminderRepeatType.once => '仅一次',
    ReminderRepeatType.daily => '每天',
    ReminderRepeatType.weekly => '每周',
    ReminderRepeatType.monthly => '每月',
  };
}

extension ThemeModeSettingLabel on ThemeModeSetting {
  String get label => switch (this) {
    ThemeModeSetting.system => '跟随系统',
    ThemeModeSetting.light => '浅色',
    ThemeModeSetting.dark => '深色',
  };
}

extension FocusSessionKindLabel on FocusSessionKind {
  String get label => switch (this) {
    FocusSessionKind.focus => '专注',
    FocusSessionKind.shortBreak => '短休息',
    FocusSessionKind.longBreak => '长休息',
  };
}

extension FocusTimerModeLabel on FocusTimerMode {
  String get label => switch (this) {
    FocusTimerMode.countUp => '正计时',
    FocusTimerMode.countDown => '倒计时',
  };
}

extension RecurrenceFrequencyLabel on RecurrenceFrequency {
  String get label => switch (this) {
    RecurrenceFrequency.daily => '每天',
    RecurrenceFrequency.weekly => '每周',
    RecurrenceFrequency.monthly => '每月',
    RecurrenceFrequency.yearly => '每年',
  };
}
