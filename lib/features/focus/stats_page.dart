/// 统计页。
///
/// 只读 `focus_sessions`，不落任何汇总表：一年最多几千条，一次查询在内存里
/// 聚合完，比维护一张会过期的汇总表简单得多，也不会出现「汇总表和明细对不上」
/// 这种必须靠定时任务修的毛病。
///
/// 全部数字都来自 `lib/core/focus/focus_stats.dart` 的纯函数——口径要能脱离
/// 数据库单测，不然统计口径错了只会安静地画出一张骗人的图。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/focus/focus_stats.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import 'widgets/focus_card.dart';
import 'widgets/heatmap.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  /// 柱状图看哪一档。
  FocusSpan _span = FocusSpan.day;

  /// 热力图是年视图还是月视图。
  bool _yearView = false;

  /// 月视图当前显示的那个月的 1 号（本地零点）。
  late int _monthStart;

  @override
  void initState() {
    super.initState();
    _monthStart = monthStartOf(dayOnlyMillis(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FocusStats> stats = ref.watch(focusStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: SafeArea(
            child: stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stack) => _StatsError(
                message: '$error',
                onRetry: () => ref.invalidate(focusStatsProvider),
              ),
              data: (FocusStats data) =>
                  data.isEmpty ? const _StatsEmpty() : _buildBody(data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(FocusStats stats) {
    final int today = stats.to;
    final List<FocusPeriodTotal> buckets = _recentBuckets(stats);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        _SummaryCard(stats: stats),
        const SizedBox(height: 12),
        _StreakCard(stats: stats, today: today),
        const SizedBox(height: 12),
        _HoursCard(stats: stats, onTapBar: _showText),
        const SizedBox(height: 12),
        FocusCard(
          title: '时长分布',
          subtitle: _spanHint(),
          trailing: SegmentedButton<FocusSpan>(
            showSelectedIcon: false,
            segments: <ButtonSegment<FocusSpan>>[
              for (final FocusSpan span in FocusSpan.values)
                ButtonSegment<FocusSpan>(
                  value: span,
                  label: Text(_spanLabel(span)),
                ),
            ],
            selected: <FocusSpan>{_span},
            onSelectionChanged: (Set<FocusSpan> selection) =>
                setState(() => _span = selection.first),
          ),
          child: _BarChart(
            bars: <_Bar>[
              for (final FocusPeriodTotal total in buckets)
                _Bar(
                  label: _bucketLabel(total.start),
                  tooltip:
                      '${_bucketTitle(total.start)}：'
                      '${formatSecondsText(total.seconds)}，'
                      '${total.sessions} 次',
                  seconds: total.seconds,
                ),
            ],
            barWidth: buckets.length > 7 ? 12 : 24,
            onTapBar: _showText,
          ),
        ),
        const SizedBox(height: 12),
        _heatmapCard(stats),
      ],
    );
  }

  /// 柱状图看几档：日看最近 7 天，周看最近 12 周，月看最近 12 个月。
  int get _bucketCount => _span == FocusSpan.day ? 7 : 12;

  String _spanLabel(FocusSpan span) => switch (span) {
    FocusSpan.day => '日',
    FocusSpan.week => '周',
    FocusSpan.month => '月',
  };

  String _spanHint() => switch (_span) {
    FocusSpan.day => '最近 7 天',
    FocusSpan.week => '最近 12 周，按周一开头算',
    FocusSpan.month => '最近 12 个月',
  };

  /// 最近的 [n] 个桶，**含空桶**。
  ///
  /// 空桶不能省：省掉的话「这周没练」和「上周练了」会并排贴在一起，
  /// 图上就看不出中间断了一段，而那恰恰是最该被看见的信息。
  List<FocusPeriodTotal> _recentBuckets(FocusStats stats) {
    final Map<int, FocusPeriodTotal> byStart = <int, FocusPeriodTotal>{
      for (final FocusPeriodTotal total in groupBySpan(stats.days, _span))
        total.start: total,
    };
    final DateTime last = fromUtcMillis(switch (_span) {
      FocusSpan.day => stats.to,
      FocusSpan.week => weekStartOf(stats.to),
      FocusSpan.month => monthStartOf(stats.to),
    });
    final List<int> starts = <int>[];
    DateTime cursor = last;
    for (int i = 0; i < _bucketCount; i++) {
      starts.add(dayOnlyMillis(cursor));
      cursor = switch (_span) {
        FocusSpan.day => DateTime(cursor.year, cursor.month, cursor.day - 1),
        FocusSpan.week => DateTime(cursor.year, cursor.month, cursor.day - 7),
        FocusSpan.month => DateTime(cursor.year, cursor.month - 1),
      };
    }
    return <FocusPeriodTotal>[
      for (final int start in starts.reversed)
        // 最早那一格可能只有一部分落在窗口里（窗口是 365 天，不是整周整月），
        // 它的合计只统计窗口内的那些天。图上给的是「看得见的那部分」。
        byStart[start] ??
            FocusPeriodTotal(
              start: start,
              seconds: 0,
              sessions: 0,
              daysWithData: 0,
            ),
    ];
  }

  String _bucketLabel(int start) {
    final DateTime date = fromUtcMillis(start);
    return switch (_span) {
      FocusSpan.day => '${date.month}/${date.day}',
      FocusSpan.week => '${date.month}/${date.day}',
      FocusSpan.month => '${date.month} 月',
    };
  }

  String _bucketTitle(int start) {
    final DateTime date = fromUtcMillis(start);
    return switch (_span) {
      FocusSpan.day => formatLocalDate(date),
      FocusSpan.week => '${formatLocalDate(date)} 那一周',
      FocusSpan.month => '${date.year} 年 ${date.month} 月',
    };
  }

  Widget _heatmapCard(FocusStats stats) {
    final DateTime current = fromUtcMillis(_monthStart);
    final bool canBack = monthStartOf(dayOnlyMillis(current)) >= stats.from;
    final bool canForward = _monthStart < monthStartOf(stats.to);
    final List<FocusDaySummary> monthDays = _monthDays(stats);
    int monthTotal = 0;
    int monthRecorded = 0;
    for (final FocusDaySummary day in monthDays) {
      monthTotal += day.seconds;
      if (day.hasTime) monthRecorded++;
    }

    return FocusCard(
      title: '专注日历',
      subtitle: _yearView
          ? '最近一年（${formatLocalDate(fromUtcMillis(stats.from))} 起）'
          : '这个月共 ${formatSecondsText(monthTotal)}，有记录 $monthRecorded 天',
      trailing: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: false, label: Text('月视图')),
          ButtonSegment<bool>(value: true, label: Text('年视图')),
        ],
        selected: <bool>{_yearView},
        onSelectionChanged: (Set<bool> selection) =>
            setState(() => _yearView = selection.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_yearView) ...<Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: '上一个月',
                  onPressed: canBack ? () => _stepMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${current.year} 年 ${current.month} 月',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下一个月',
                  onPressed: canForward ? () => _stepMonth(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FocusMonthHeatmap(
              monthDays: monthDays,
              today: stats.to,
              onTapDay: _showDay,
            ),
          ] else
            FocusYearHeatmap(
              days: stats.days,
              today: stats.to,
              onTapDay: _showDay,
            ),
          const SizedBox(height: 14),
          const FocusHeatLegend(),
        ],
      ),
    );
  }

  List<FocusDaySummary> _monthDays(FocusStats stats) {
    final DateTime first = fromUtcMillis(_monthStart);
    final int count = lastDayOfMonth(first.year, first.month);
    return <FocusDaySummary>[
      for (int i = 0; i < count; i++)
        stats.dayAt(
              dayOnlyMillis(DateTime(first.year, first.month, first.day + i)),
            ) ??
            FocusDaySummary(
              day: dayOnlyMillis(
                DateTime(first.year, first.month, first.day + i),
              ),
              seconds: 0,
              sessions: 0,
            ),
    ];
  }

  void _stepMonth(int delta) {
    final DateTime current = fromUtcMillis(_monthStart);
    setState(() {
      _monthStart = dayOnlyMillis(
        DateTime(current.year, current.month + delta),
      );
    });
  }

  void _showDay(FocusDaySummary day) => _showText(focusHeatSemantics(day));

  void _showText(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});

  final FocusStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FocusCard(
      title: '最近一年',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            formatSecondsText(stats.total),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '共 ${stats.sessionCount} 次专注，有记录 ${stats.daysWithData} 天。',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats, required this.today});

  final FocusStats stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int current = stats.currentStreak(today);
    final int longest = stats.longestStreak();
    final bool todayHasTime = stats.dayAt(today)?.hasTime ?? false;
    return FocusCard(
      title: '连续天数',
      subtitle: todayHasTime ? '今天已经记上了。' : '今天还没开始，不算断。',
      child: Row(
        children: <Widget>[
          _Figure(label: '现在', value: '$current 天'),
          const SizedBox(width: 32),
          _Figure(label: '最长', value: '$longest 天'),
          const Spacer(),
          Icon(
            Icons.local_fire_department_outlined,
            color: current > 0
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.stats, required this.onTapBar});

  final FocusStats stats;
  final ValueChanged<String> onTapBar;

  @override
  Widget build(BuildContext context) {
    final int? peak = peakHour(stats.hours);
    final List<_Bar> bars = <_Bar>[
      for (int hour = 0; hour < 24; hour++)
        _Bar(
          // 二十四个标签挤在一起谁也读不清，每三小时标一个。
          label: hour % 3 == 0 ? '$hour' : '',
          tooltip: '$hour 点这一小时：${formatSecondsText(stats.hours[hour] ?? 0)}',
          seconds: stats.hours[hour] ?? 0,
        ),
    ];
    return FocusCard(
      title: '高效时段',
      subtitle: peak == null
          ? '还没有足够的数据——有了记录才谈得上「几点最坐得住」。'
          : '最坐得住的是 $peak 点这一小时'
                '（${formatSecondsText(stats.hours[peak] ?? 0)}）。',
      child: _BarChart(bars: bars, barWidth: 8, onTapBar: onTapBar),
    );
  }
}

/// 柱状图里的一根柱子。
class _Bar {
  const _Bar({
    required this.label,
    required this.tooltip,
    required this.seconds,
  });

  final String label;
  final String tooltip;
  final int seconds;
}

/// 自绘的柱状图。
///
/// 高度按**这一批里最大的那根**归一化，而不是按固定阈值：日 / 周 / 月三档
/// 的量级差几十倍，钉死一个上限的话「看月」会全是贴地的线。
class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars, required this.barWidth, this.onTapBar});

  final List<_Bar> bars;
  final double barWidth;
  final ValueChanged<String>? onTapBar;

  /// 柱子区的高度。
  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    int maxSeconds = 0;
    for (final _Bar bar in bars) {
      if (bar.seconds > maxSeconds) maxSeconds = bar.seconds;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final _Bar bar in bars)
          Expanded(
            child: Tooltip(
              message: bar.tooltip,
              excludeFromSemantics: true,
              child: InkWell(
                onTap: onTapBar == null ? null : () => onTapBar!(bar.tooltip),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      height: height,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: barWidth,
                          // 有一点就得看得见：几分钟的柱子按比例算只有 1 像素，
                          // 那和「没有」在图上是同一个样子。
                          height: bar.seconds <= 0
                              ? 2
                              : (bar.seconds / maxSeconds * height).clamp(
                                  3,
                                  height,
                                ),
                          decoration: BoxDecoration(
                            color: bar.seconds <= 0
                                ? scheme.surfaceContainerHighest
                                : scheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bar.label,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 一条记录都没有时的空态。
///
/// 空态不是「画一张全 0 的图」：全 0 的图看起来像「你什么都没做到」，
/// 而真实情况是「还没开始用」。
class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('还没有专注记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '去「专注」开一段计时，这里会长出热力图、连续天数和高效时段。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(AppRoutes.focus),
              child: const Text('去专注'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('统计读不出来了', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
