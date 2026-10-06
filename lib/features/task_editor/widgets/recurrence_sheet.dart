import 'package:flutter/material.dart';

import '../../../core/models/enum_labels.dart';
import '../../../core/models/enums.dart';
import '../../../core/recurrence/recurrence_rule.dart';
import '../../../core/recurrence/recurrence_text.dart';
import '../../../core/utils/time.dart';

/// 重复设置弹窗。返回 `null` = 用户取消。
///
/// [anchor] 是系列的第 1 次，也就是任务自己的截止日期：规则里所有日期都从
/// 它推算。它由调用方给，因为这个弹窗只负责「多久重复一次」，不负责选日期
/// ——日期在编辑页那一行上。
Future<RecurrenceRule?> showRecurrenceSheet(
  BuildContext context, {
  required RecurrenceRule? initial,
  required DateTime anchor,
}) {
  return showModalBottomSheet<RecurrenceRule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _RecurrenceSheet(initial: initial, anchor: anchor),
  );
}

enum _EndMode { forever, count, date }

class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({required this.initial, required this.anchor});

  final RecurrenceRule? initial;
  final DateTime anchor;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  /// 间隔上限。再大就不是「重复」而是「另一件事」了，而且列表里排到十年
  /// 之后的任务对用户没有任何意义。
  static const int _maxInterval = 99;

  /// 次数上限。用户真要「共 100 次以上」，用结束日期表达更清楚。
  static const int _maxCount = 99;

  late RecurrenceFrequency _frequency;
  late int _interval;
  late Set<int> _weekdays;
  late Set<int> _monthDays;
  late _EndMode _endMode;
  late int _endCount;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final RecurrenceRule? initial = widget.initial;
    _frequency = initial?.frequency ?? RecurrenceFrequency.daily;
    _interval = initial?.interval ?? 1;
    _weekdays = <int>{...?initial?.byWeekday};
    _monthDays = <int>{...?initial?.byMonthDay};
    _endCount = initial?.endCount ?? 10;
    _endDate = initial?.endDate;
    _endMode = initial == null
        ? _EndMode.forever
        : initial.endCount != null
        ? _EndMode.count
        : initial.endDate != null
        ? _EndMode.date
        : _EndMode.forever;
  }

  RecurrenceRule _draft() => RecurrenceRule(
    startsOn: widget.anchor,
    frequency: _frequency,
    interval: _interval,
    byWeekday: _frequency == RecurrenceFrequency.weekly
        ? _weekdays
        : const <int>{},
    byMonthDay: _frequency == RecurrenceFrequency.monthly
        ? _monthDays
        : const <int>{},
    endDate: _endMode == _EndMode.date ? _endDate : null,
    endCount: _endMode == _EndMode.count ? _endCount : null,
  ).normalized();

  void _changeFrequency(RecurrenceFrequency next) {
    if (next == _frequency) return;
    setState(() {
      _frequency = next;
      // 换频率就丢掉另一个频率的专属选择：留着的话，从「每周一」改成
      // 「每月」再改回每周，那个星期一会自己复活，而用户以为它早没了。
      _weekdays = <int>{};
      _monthDays = <int>{};
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime first = DateTime(
      widget.anchor.year,
      widget.anchor.month,
      widget.anchor.day,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime(first.year + 1, first.month, first.day),
      // 下界就是系列的第 1 天：结束日期早于开始日期是没有意义的规则，
      // 让它选不出来比事后把它当作废更好。
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RecurrenceRule draft = _draft();
    final String? next = nextOccurrenceText(draft, now: DateTime.now());

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('重复', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),

                    const _Label('频率'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final RecurrenceFrequency value
                            in RecurrenceFrequency.values)
                          ChoiceChip(
                            label: Text(value.label),
                            selected: _frequency == value,
                            onSelected: (_) => _changeFrequency(value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const _Label('间隔'),
                    _Counter(
                      value: _interval,
                      min: 1,
                      max: _maxInterval,
                      suffix: _intervalSuffix(),
                      onChanged: (int value) =>
                          setState(() => _interval = value),
                    ),
                    const SizedBox(height: 20),

                    if (_frequency == RecurrenceFrequency.weekly) ...<Widget>[
                      const _Label('星期几'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (int day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(_weekdayName(day)),
                              selected: _weekdays.contains(day),
                              onSelected: (_) => setState(() {
                                if (!_weekdays.remove(day)) _weekdays.add(day);
                              }),
                            ),
                        ],
                      ),
                      const _Hint('一个都不选就是和起始日同一个星期几。'),
                      const SizedBox(height: 20),
                    ],

                    if (_frequency == RecurrenceFrequency.monthly) ...<Widget>[
                      const _Label('每月几号'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (int day = 1; day <= 31; day++)
                            FilterChip(
                              // 31 个号数挤在一起，标签比默认的芯片窄一档才放得下。
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text('$day'),
                              selected: _monthDays.contains(day),
                              onSelected: (_) => setState(() {
                                if (!_monthDays.remove(day)) {
                                  _monthDays.add(day);
                                }
                              }),
                            ),
                        ],
                      ),
                      const _Hint('一个都不选就是和起始日同一个号数。29 号以后遇到短月会落到月末。'),
                      const SizedBox(height: 20),
                    ],

                    const _Label('结束'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('一直重复'),
                          selected: _endMode == _EndMode.forever,
                          onSelected: (_) =>
                              setState(() => _endMode = _EndMode.forever),
                        ),
                        ChoiceChip(
                          label: const Text('重复几次'),
                          selected: _endMode == _EndMode.count,
                          onSelected: (_) =>
                              setState(() => _endMode = _EndMode.count),
                        ),
                        ChoiceChip(
                          label: const Text('到某天为止'),
                          selected: _endMode == _EndMode.date,
                          onSelected: (_) =>
                              setState(() => _endMode = _EndMode.date),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_endMode == _EndMode.count)
                      _Counter(
                        value: _endCount,
                        min: 1,
                        max: _maxCount,
                        suffix: '次（含第 1 次）',
                        onChanged: (int value) =>
                            setState(() => _endCount = value),
                      ),
                    if (_endMode == _EndMode.date)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(
                          _endDate == null
                              ? '选择结束日期'
                              : formatLocalDate(_endDate!),
                        ),
                        onPressed: _pickEndDate,
                      ),
                    const SizedBox(height: 20),

                    // 预览放在按钮上面：改完设置先看到结果，再决定存不存。
                    _Preview(
                      text: next == null ? '按这套设置没有下一次了。' : '下一次：$next',
                      warning: next == null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // 按钮固定在底下，不跟着内容滚：七个星期几或三十一个号数的芯片
            // 会把内容堆得很高，让「保存」滑出屏幕是个很别扭的设计。
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    // 结束日期模式下没选日期就存，等于设了一条「永不结束」
                    // 的规则——那和用户点的按钮不是一件事。
                    onPressed: _endMode == _EndMode.date && _endDate == null
                        ? null
                        : () => Navigator.of(context).pop(_draft()),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _intervalSuffix() => switch (_frequency) {
    RecurrenceFrequency.daily => '天',
    RecurrenceFrequency.weekly => '周',
    RecurrenceFrequency.monthly => '个月',
    RecurrenceFrequency.yearly => '年',
  };
}

String _weekdayName(int weekday) =>
    const <String>['一', '二', '三', '四', '五', '六', '日'][weekday - 1];

/// 一个 `− 3 +` 的行。数字用步进而不是输入框：这两个值都小、都有明显的
/// 边界，加减比调出键盘点几下要快，也不会出现「输入了 0」这种非法值。
class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: '减少',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '增加',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
        const SizedBox(width: 8),
        Text(suffix),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          warning ? Icons.error_outline : Icons.event_available_outlined,
          size: 18,
          color: warning ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: warning ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
