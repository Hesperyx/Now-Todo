/// 自绘的热力图。
///
/// 用 [Wrap] 和小方块手画，不引图表依赖：要画的东西只有方格，一个依赖
/// 换来的是额外的编译时间、一套要跟着主题调的默认样式，以及「颜色改了
/// 却不由我说了算」。这里每一格的颜色都从 `ColorScheme` 现取。
library;

import 'package:flutter/material.dart';

import '../../../core/focus/focus_stats.dart';
import '../../../core/theme/heat_colors.dart';
import '../../../core/utils/time.dart';

/// 那一天在给读屏软件的眼里是什么。
String focusHeatSemantics(FocusDaySummary day) {
  final String date = formatLocalDate(fromUtcMillis(day.day));
  if (day.isEmpty) return '$date，没有专注记录';
  if (!day.hasTime) return '$date，有 ${day.sessions} 次记录，但没计时';
  return '$date，专注 ${formatSecondsText(day.seconds)}，${day.sessions} 次';
}

/// 图例。
///
/// 五档颜色没有文字说明就是五个看不懂的方块，所以它和热力图是绑在一起用的。
class FocusHeatLegend extends StatelessWidget {
  const FocusHeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const List<(FocusHeat, String)> entries = <(FocusHeat, String)>[
      (FocusHeat.none, '无记录'),
      (FocusHeat.zero, '来过没计时'),
      (FocusHeat.light, '<15 分钟'),
      (FocusHeat.medium, '15–60 分钟'),
      (FocusHeat.heavy, '≥1 小时'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: <Widget>[
        for (final (FocusHeat heat, String label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: focusHeatColor(scheme, heat),
                  borderRadius: BorderRadius.circular(3),
                  border: heat == FocusHeat.none
                      ? Border.all(color: scheme.outlineVariant)
                      : null,
                ),
              ),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

/// 月视图：七列排满一个月，格子里带日期数字。
class FocusMonthHeatmap extends StatelessWidget {
  const FocusMonthHeatmap({
    required this.monthDays,
    required this.today,
    this.onTapDay,
    super.key,
  });

  /// 这一个月的每一天，从 1 号到月末，连续。
  final List<FocusDaySummary> monthDays;

  /// 今天的本地零点，用来给今天描一圈。
  final int today;

  final ValueChanged<FocusDaySummary>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    const List<String> weekdayLabels = <String>[
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '日',
    ];
    const double gap = 6;

    if (monthDays.isEmpty) return const SizedBox.shrink();
    // 1 号是星期几，前面就要空几格，否则整个月会错位一整列。
    final int leading = fromUtcMillis(monthDays.first.day).weekday - 1;
    final List<Widget?> cells = <Widget?>[
      ...List<Widget?>.filled(leading, null),
      ...monthDays.map(
        (FocusDaySummary day) => _DayCell(
          key: ValueKey<int>(day.day),
          day: day,
          today: today,
          onTap: onTapDay,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 减 0.5 是给浮点误差留的余量：七个格子加六条间隙算下来正好是宽度，
        // 只要算出来多了零点几像素，第七格就会掉到下一行。
        final double cell = (constraints.maxWidth - gap * 6) / 7 - 0.5;
        final List<List<Widget?>> rows = <List<Widget?>>[];
        for (int i = 0; i < cells.length; i += 7) {
          rows.add(
            cells.sublist(i, i + 7 > cells.length ? cells.length : i + 7),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (final String label in weekdayLabels)
                  SizedBox(
                    width: cell,
                    child: Center(
                      child: Text(
                        label,
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                // 每行之间的间隙也要在表头这一行留出来，否则表头与格子对不齐。
                for (int i = 0; i < 6; i++) const SizedBox(width: gap),
              ],
            ),
            const SizedBox(height: 4),
            for (final List<Widget?> row in rows) ...<Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < 7; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: row.length > i && row[i] != null
                          ? row[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
              if (row != rows.last) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}

/// 年视图：十二个小月份格。
///
/// 不按「53 列 × 7 行」铺成一长条，是因为手机上那一长条每格只有 4–5 像素，
/// 看不清也说不出「哪个月好」；按月份成块之后，一个月里有没有断档是一眼的事。
class FocusYearHeatmap extends StatelessWidget {
  const FocusYearHeatmap({
    required this.days,
    required this.today,
    this.onTapDay,
    super.key,
  });

  /// 窗口内的连续日期。
  final List<FocusDaySummary> days;

  final int today;

  final ValueChanged<FocusDaySummary>? onTapDay;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final Map<int, List<FocusDaySummary>> byMonth =
        <int, List<FocusDaySummary>>{};
    for (final FocusDaySummary day in days) {
      byMonth
          .putIfAbsent(monthStartOf(day.day), () => <FocusDaySummary>[])
          .add(day);
    }
    final List<int> months = byMonth.keys.toList()..sort();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 窄屏三个一行，宽一点四个一行——再宽下去每格会大到不像热力图。
        final int perRow = constraints.maxWidth < 420 ? 3 : 4;
        const double gap = 12;
        final double blockWidth =
            (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: <Widget>[
            for (final int month in months)
              SizedBox(
                width: blockWidth,
                child: _MonthBlock(
                  monthStart: month,
                  days: byMonth[month] ?? const <FocusDaySummary>[],
                  today: today,
                  onTapDay: onTapDay,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthBlock extends StatelessWidget {
  const _MonthBlock({
    required this.monthStart,
    required this.days,
    required this.today,
    required this.onTapDay,
  });

  final int monthStart;
  final List<FocusDaySummary> days;
  final int today;
  final ValueChanged<FocusDaySummary>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime first = fromUtcMillis(monthStart);
    const double gap = 2;
    int total = 0;
    for (final FocusDaySummary day in days) {
      total += day.seconds;
    }
    final int leading = first.weekday - 1;
    final List<Widget?> cells = <Widget?>[
      ...List<Widget?>.filled(leading, null),
      ...days.map(
        (FocusDaySummary day) => _DayCell(
          // 带上是哪一天的 key，测试与将来做「点开某天」都能直接用。
          key: ValueKey<int>(day.day),
          day: day,
          today: today,
          onTap: onTapDay,
          showNumber: false,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cell = (constraints.maxWidth - gap * 6) / 7 - 0.5;
        final List<List<Widget?>> rows = <List<Widget?>>[];
        for (int i = 0; i < cells.length; i += 7) {
          rows.add(
            cells.sublist(i, i + 7 > cells.length ? cells.length : i + 7),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${first.month} 月', style: text.labelMedium),
            const SizedBox(height: 2),
            Text(
              total == 0 ? '没有时长' : formatSecondsText(total),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            for (final List<Widget?> row in rows) ...<Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < 7; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: row.length > i && row[i] != null
                          ? row[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
              if (row != rows.last) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.onTap,
    this.showNumber = true,
    super.key,
  });

  final FocusDaySummary day;
  final int today;
  final ValueChanged<FocusDaySummary>? onTap;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final FocusHeat heat = heatOf(day);
    final bool isToday = day.day == today;
    return Semantics(
      label: focusHeatSemantics(day),
      button: onTap != null,
      child: Tooltip(
        message: focusHeatSemantics(day),
        // 读屏软件用的标签由外面的 Semantics 给，这里只管鼠标悬停与长按。
        excludeFromSemantics: true,
        child: Material(
          color: focusHeatColor(scheme, heat),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(day),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: heat == FocusHeat.none
                      ? scheme.outlineVariant
                      : Colors.transparent,
                ),
              ),
              foregroundDecoration: isToday
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: scheme.onSurface, width: 1.5),
                    )
                  : null,
              alignment: Alignment.center,
              child: showNumber
                  ? Text(
                      '${fromUtcMillis(day.day).day}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onFocusHeatColor(scheme, heat),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
