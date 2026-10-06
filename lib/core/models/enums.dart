/// 领域枚举。
///
/// ⚠️ **声明顺序就是数据库里的存储值。**
/// drift 的 `intEnum` 用枚举的 `index` 落库，所以这些枚举：
///
/// - 只能**往后追加**新成员；
/// - **不能**重排、不能删除中间的成员、不能在中间插入。
///
/// 一旦违反，已有数据的含义会静默错位（不是崩溃，是更难查的错）。
/// 确实需要调整语义时，请提升 `schemaVersion` 并写数据迁移，
/// 见 `docs/ARCHITECTURE.md` §6。
library;

/// 任务优先级。
enum TaskPriority { none, low, medium, high }

/// 任务完成状态。
///
/// 首版只有两态。**不要**在这里加「进行中」之类的中间态——
/// PRD 的首版范围里没有，加了会让所有查询都要重新想一遍。
enum TaskStatus { pending, completed }

/// 重复任务的频率。
enum RecurrenceFrequency {
  /// 每天。
  daily,

  /// 每周。
  weekly,

  /// 每月。按「第几个同日」推进，遇到 31 号在短月自动落到月末。
  monthly,

  /// 每年。
  yearly,
}

/// 提醒的重复方式。
///
/// `once` 表示到点响一次；其余值用于「任务没做，到了下一个周期再响一次」。
enum ReminderRepeatType { once, daily, weekly, monthly }

/// 应用外观模式。
enum ThemeModeSetting { system, light, dark }

/// 首页默认展示的视图。
enum DefaultView { today, all, completed }

/// 一条专注会话的类型。
///
/// 休息也算会话：它们同样占用了时间，同样要落库，否则「专注了多久」的统计
/// 里会夹进休息时长而不自知。
enum FocusSessionKind { focus, shortBreak, longBreak }

/// 计时器的走向。
///
/// 两种模式共用同一套字段（`startedAt` / `pausedMillis` / `pausedAt`），
/// 差别只在「有没有一个终点」：倒计时有 `plannedSeconds`，走满了算完成；
/// 正计时没有终点，用户按停就是结束。**不要**为它们写两套状态机。
enum FocusTimerMode { countUp, countDown }
