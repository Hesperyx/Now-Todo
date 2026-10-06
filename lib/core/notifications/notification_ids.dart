/// 通知 id 与通知渠道 id 的集中定义。
///
/// 这些字符串和数字一旦发布就不能改：系统按 id 取消已排期的通知，
/// 改一次就意味着用户升级后手上还留着一条永远取消不掉的旧通知。
library;

/// 通知 id 的分配规则。
///
/// **为什么要有区间划分**：提醒的通知 id 是由提醒记录 id 算出来的哈希，
/// 计时通知用的是固定值。如果两者共用一个空间，哈希撞上固定值就会让
/// 「计时进行中」的常驻通知顶掉一条任务提醒 —— 概率很低，但一旦发生
/// 极难复现。把低位区间留给应用自己，就是让这种碰撞在构造上不可能发生。
abstract final class NotificationIds {
  /// 计时进行中的常驻通知（前台服务用）。
  static const int focusOngoing = 1;

  /// 倒计时走满 / 休息结束的提示。
  static const int focusFinished = 2;

  /// 提醒通知的起始 id。低于它的值全部留给应用自己的固定通知。
  static const int _reminderBase = 1000;

  /// 提醒通知可用的 id 数量。
  static const int _reminderRange = 0x7fffffff - _reminderBase;

  /// 由提醒记录 id 推导出稳定的通知 id。
  ///
  /// 不用 `String.hashCode`：Dart 只保证它在**同一次运行内**一致，没有跨
  /// 版本、跨平台的稳定性承诺。而这里恰恰要求「今天排的，明天还能按同一个
  /// id 取消掉」，所以自己实现一个确定性的哈希。
  static int forReminder(String reminderId) =>
      _reminderBase + stableHash(reminderId) % _reminderRange;

  /// 判断一个通知 id 是否属于提醒区间。
  static bool isReminder(int notificationId) => notificationId >= _reminderBase;
}

/// 通知渠道 id。
///
/// 渠道是 Android 8.0 起的概念：**重要度在创建后由用户在系统设置里决定，
/// 应用改不了**。所以一个渠道对应一种「用户打算怎么被打断」的语义，
/// 而不是一种消息类型 —— 混用会让用户没法只关掉其中一半。
abstract final class NotificationChannels {
  /// 任务提醒。重要度「高」，会响会震。
  static const String reminders = 'now_todo_reminders';

  /// 专注计时的常驻进度。重要度「低」，不出声 —— 它一直在屏幕上，
  /// 每次刷新都响一声的话这个功能没法用。
  static const String focusOngoing = 'now_todo_focus_ongoing';

  /// 专注结束 / 休息开始的提示。重要度「高」。
  static const String focusAlerts = 'now_todo_focus_alerts';
}

/// 确定性的 32 位 FNV-1a 哈希，取低 31 位。
///
/// 取低 31 位是为了保证非负：Android 的通知 id 是 `jint`，负数虽然合法，
/// 但和「未设置」的哨兵值放在一起看很容易读错。
int stableHash(String input) {
  const int offsetBasis = 0x811c9dc5;
  const int prime = 0x01000193;
  int hash = offsetBasis;
  for (final int unit in input.codeUnits) {
    hash = ((hash ^ (unit & 0xff)) * prime) & 0xffffffff;
    hash = ((hash ^ ((unit >> 8) & 0xff)) * prime) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
