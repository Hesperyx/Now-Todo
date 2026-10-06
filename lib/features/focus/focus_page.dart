import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/focus/focus_settings.dart';
import '../../core/focus/focus_stats.dart';
import '../../core/focus/focus_timer.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../data/repositories/focus_session_repository.dart';

/// 专注计时页：一个会话从开始到结束要走完的那条线。
///
/// **每秒重绘的不是状态。** 页面只持有「现在几点」这一个会变的东西，
/// 其余全部由库里那条会话的时间戳推出来 —— 所以切后台、锁屏、被系统压制
/// 都不会让时长漂移，回到前台接着按 `DateTime.now()` 算就是了。
class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key, this.taskId});

  /// 从任务详情页进来时带上，开始的那一刻就挂到这条任务上。
  final String? taskId;

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  final TextEditingController _minutesInput = TextEditingController();

  Timer? _ticker;
  DateTime _now = DateTime.now();

  FocusSessionKind _kind = FocusSessionKind.focus;
  FocusTimerMode? _mode;
  int? _minutes;
  String? _minutesError;
  String? _taskId;
  bool _busy = false;
  bool _finishHandled = false;

  @override
  void initState() {
    super.initState();
    _taskId = widget.taskId;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _minutesInput.dispose();
    super.dispose();
  }

  /// 只在一段会话跑着的时候才每秒重绘。
  ///
  /// 空闲时也嘀嗒的话，这一页会在没人看的地方每秒重建一次，而它上面
  /// 还是整个 `SegmentedButton` 组成的表单。
  void _setTicking(bool ticking) {
    if (ticking && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (Timer _) => _tick(),
      );
    } else if (!ticking && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    final TodoFocusSession? session = ref
        .read(runningSessionProvider)
        .valueOrNull;
    if (session == null) return;
    // 倒计时走满：前台时由界面收尾，后台时那条兜底通知会先响。
    if (session.toTimerState().isFinished(_now)) {
      unawaited(_completeCountdown(session));
    }
  }

  Future<void> _guard(Future<void> Function() action, String what) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      _report('$what失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 当前设置。
  ///
  /// 退路是 `initialPreferencesProvider` 而不是 `const AppPreferences()`：
  /// 启动时那份快照是真的从库里读出来的，而默认值只是「没读到」。用默认值
  /// 顶替会让 `_start()` 拿默认时长开工、让 `_completeCountdown()` 按
  /// `autoStartNext == false` 停下 —— 全都发生在用户看不见的地方。
  AppPreferences get _prefs =>
      ref.read(preferencesProvider).valueOrNull ??
      ref.read(initialPreferencesProvider);

  FocusTimerMode _modeOf(AppPreferences prefs) =>
      _mode ?? prefs.defaultTimerMode;

  int _minutesOf(AppPreferences prefs) =>
      _minutes ??
      prefs
          .minutesFor(_kind)
          .clamp(minutesRangeFor(_kind).min, minutesRangeFor(_kind).max);

  /// 今天已经开出过几段专注。用来决定下一次休息是短的还是长的。
  Future<int> _focusRoundsToday() async {
    final int today = dayOnlyMillis(DateTime.now());
    final List<TodoFocusSession> todays = await ref
        .read(focusSessionRepositoryProvider)
        .listBetween(from: today, to: today);
    return todays
        .where((TodoFocusSession s) => s.kind == FocusSessionKind.focus)
        .length;
  }

  Future<void> _start({
    FocusSessionKind? kind,
    String? taskId,
    bool keepTask = false,
  }) async {
    final AppPreferences prefs = _prefs;
    final FocusSessionKind target = kind ?? _kind;
    final FocusTimerMode mode = _modeOf(prefs);
    final int minutes = kind == null || kind == _kind
        ? _minutesOf(prefs)
        : prefs.minutesFor(target);
    final DateTime now = DateTime.now();
    await ref
        .read(focusSessionRepositoryProvider)
        .start(
          at: now,
          // 冻在写入这一刻，不再回头看 —— 见 logicalDateFor 的说明。
          logicalDate: logicalDateFor(
            now.utcMillis,
            midnightMode: prefs.midnightMode,
            midnightEndHour: prefs.midnightEndHour,
          ),
          taskId: keepTask ? null : (taskId ?? _taskId),
          kind: target,
          mode: mode,
          plan: mode == FocusTimerMode.countDown
              ? Duration(minutes: minutes)
              : null,
        );
    if (mounted) setState(() => _finishHandled = false);
  }

  /// 倒计时自己走满了：收尾，然后按设置决定接续还是停下。
  Future<void> _completeCountdown(TodoFocusSession session) async {
    if (_finishHandled || _busy) return;
    _finishHandled = true;
    await _guard(() async {
      final DateTime now = DateTime.now();
      await ref
          .read(focusSessionRepositoryProvider)
          .finish(session.id, at: now);
      if (!mounted) return;
      final AppPreferences prefs = _prefs;
      if (prefs.autoStartNext) {
        await _startAutoNext(session.kind, prefs);
      } else {
        await _showFinishSheet(session);
      }
    }, '结束');
  }

  Future<void> _startAutoNext(
    FocusSessionKind justEnded,
    AppPreferences prefs,
  ) async {
    final FocusSessionKind next = justEnded == FocusSessionKind.focus
        ? breakAfterFocus(
            completedFocusRounds: await _focusRoundsToday(),
            roundsBeforeLongBreak: prefs.roundsBeforeLongBreak,
          )
        : kindAfterBreak();
    await _start(kind: next, keepTask: next == FocusSessionKind.focus);
  }

  Future<void> _pause(TodoFocusSession session) => _guard(() async {
    await ref
        .read(focusSessionRepositoryProvider)
        .pause(session.id, DateTime.now());
  }, '暂停');

  Future<void> _resume(TodoFocusSession session) => _guard(() async {
    await ref
        .read(focusSessionRepositoryProvider)
        .resume(session.id, DateTime.now());
  }, '恢复');

  Future<void> _finish(TodoFocusSession session) => _guard(() async {
    await ref
        .read(focusSessionRepositoryProvider)
        .finish(session.id, at: DateTime.now());
    if (mounted) await _showFinishSheet(session);
  }, '结束');

  Future<void> _discard(TodoFocusSession session) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('放弃这一段？'),
        content: const Text('这一段不会计入统计，也没法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续计时'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await ref.read(focusSessionRepositoryProvider).cancel(session.id);
    }, '放弃');
  }

  /// 会话结束后的「记一笔」：补一个归属、写一行备注。
  ///
  /// 用底部弹层而不是对话框：它要填的东西是可选的，用户扫一眼就能关掉，
  /// 不该被一个必须回应的模态挡住。
  ///
  /// 传进来的 [session] 是结束**之前**那一份快照，`actualSeconds` 还是 0、
  /// `completed` 还是 false。所以这里先把库里那份重读一次 —— 否则弹层会
  /// 告诉刚专注了 25 分钟的人「这一段记下了 / 实际 00:00」。
  Future<void> _showFinishSheet(TodoFocusSession session) async {
    if (!mounted) return;
    final TodoFocusSession? stored = await ref
        .read(focusSessionRepositoryProvider)
        .findById(session.id);
    if (!mounted) return;
    final TodoFocusSession current = stored ?? session;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _FinishSheet(
        session: current,
        onStartNext: current.kind == FocusSessionKind.focus
            ? () => _startAutoNext(current.kind, _prefs)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TodoFocusSession?> running = ref.watch(
      runningSessionProvider,
    );
    ref.listen<AsyncValue<TodoFocusSession?>>(runningSessionProvider, (
      AsyncValue<TodoFocusSession?>? previous,
      AsyncValue<TodoFocusSession?> next,
    ) {
      _setTicking(next.valueOrNull != null);
    });
    final TodoFocusSession? session = running.valueOrNull;
    _setTicking(session != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('专注'),
        actions: <Widget>[
          IconButton(
            tooltip: '统计',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push(AppRoutes.stats),
          ),
          IconButton(
            tooltip: '徽章',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push(AppRoutes.achievements),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: SafeArea(
            child: running.isLoading && session == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: session == null
                        ? _buildSetup(context)
                        : _buildRunning(context, session),
                  ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── 未开始：设置 ───────────────────────────

  Widget _buildSetup(BuildContext context) {
    final AppPreferences prefs = _prefs;
    final FocusTimerMode mode = _modeOf(prefs);
    final int minutes = _minutesOf(prefs);
    if (_minutesInput.text != '$minutes') _minutesInput.text = '$minutes';
    final ({int min, int max}) range = minutesRangeFor(_kind);
    final bool canStart = _minutesError == null;

    return ListView(
      children: <Widget>[
        SegmentedButton<FocusSessionKind>(
          showSelectedIcon: false,
          segments: <ButtonSegment<FocusSessionKind>>[
            for (final FocusSessionKind kind in FocusSessionKind.values)
              ButtonSegment<FocusSessionKind>(
                value: kind,
                label: Text(kind.label),
              ),
          ],
          selected: <FocusSessionKind>{_kind},
          onSelectionChanged: (Set<FocusSessionKind> selection) => setState(() {
            _kind = selection.first;
            // 换类型就回到那个类型自己的默认时长，不要沿用上一个类型
            // 的数字：从 25 分钟专注切到短休息还留着 25 是件很怪的事。
            _minutes = null;
            _minutesError = null;
          }),
        ),
        const SizedBox(height: 16),
        SegmentedButton<FocusTimerMode>(
          showSelectedIcon: false,
          segments: <ButtonSegment<FocusTimerMode>>[
            for (final FocusTimerMode item in FocusTimerMode.values)
              ButtonSegment<FocusTimerMode>(
                value: item,
                label: Text(item.label),
              ),
          ],
          selected: <FocusTimerMode>{mode},
          onSelectionChanged: (Set<FocusTimerMode> selection) =>
              setState(() => _mode = selection.first),
        ),
        const SizedBox(height: 20),
        if (mode == FocusTimerMode.countDown)
          TextField(
            controller: _minutesInput,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '这一段多久',
              suffixText: '分钟',
              helperText: '可以填 ${range.min}–${range.max}',
              errorText: _minutesError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (String text) {
              final int? value = int.tryParse(text.trim());
              setState(() {
                _minutes = value;
                _minutesError = value == null
                    ? null
                    : validateMinutes(value, _kind);
              });
            },
          )
        else
          _HintCard(
            icon: Icons.all_inclusive,
            text: '正计时不限时，想停的时候自己点结束。它不会被算成「没完成」。',
          ),
        const SizedBox(height: 16),
        _TaskPicker(
          taskId: _taskId,
          onChanged: (String? id) => setState(() => _taskId = id),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: canStart ? _start : null,
          icon: const Icon(Icons.play_arrow),
          label: Text('开始${_kind.label}'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }

  /// 这段会话挂在谁头上。任务被删掉或被标成完成之后就不在未完成列表里了，
  /// 那时候如实说「找不到了」，而不是默默显示成自由专注。
  String _assignedTitle(TodoFocusSession session) {
    final String? id = session.taskId;
    if (id == null) return '自由专注';
    final List<TodoTask> tasks =
        ref.watch(pendingTasksProvider).valueOrNull ?? const <TodoTask>[];
    return tasks.where((TodoTask task) => task.id == id).firstOrNull?.title ??
        '任务已不在待办里';
  }

  // ─────────────────────────── 进行中 ───────────────────────────

  Widget _buildRunning(BuildContext context, TodoFocusSession session) {
    final ThemeData theme = Theme.of(context);
    final FocusTimerState state = session.toTimerState();
    final Duration elapsed = state.elapsed(_now);
    final Duration? remaining = state.remaining(_now);
    final bool paused = state.isPaused;

    return Column(
      children: <Widget>[
        const Spacer(),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox.expand(
                child: CircularProgressIndicator(
                  // 正计时没有终点，也就没有「完成度」可言 —— 画个空环比
                  // 编一个进度诚实。
                  value: state.progress(_now)?.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatDuration(remaining ?? elapsed),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paused
                        ? '已暂停'
                        : remaining == null
                        ? '已用这么久'
                        : '还剩',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(session.kind.label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          _assignedTitle(session),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            TextButton(
              onPressed: _busy ? null : () => _discard(session),
              child: const Text('放弃'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : paused
                  ? () => _resume(session)
                  : () => _pause(session),
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(paused ? '继续' : '暂停'),
              style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
            ),
            TextButton(
              onPressed: _busy ? null : () => _finish(session),
              child: const Text('结束'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 「给哪条任务计时」的选择器。
class _TaskPicker extends ConsumerWidget {
  const _TaskPicker({required this.taskId, required this.onChanged});

  final String? taskId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TodoTask> tasks =
        ref.watch(pendingTasksProvider).valueOrNull ?? const <TodoTask>[];
    final TodoTask? selected = tasks
        .where((TodoTask t) => t.id == taskId)
        .firstOrNull;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '挂到任务',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: selected?.id,
          hint: const Text('不挂任务'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(child: Text('不挂任务')),
            for (final TodoTask task in tasks)
              DropdownMenuItem<String?>(
                value: task.id,
                child: Text(task.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// 会话结束后的「记一笔」。
class _FinishSheet extends ConsumerStatefulWidget {
  const _FinishSheet({required this.session, this.onStartNext});

  final TodoFocusSession session;
  final Future<void> Function()? onStartNext;

  @override
  ConsumerState<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends ConsumerState<_FinishSheet> {
  late final TextEditingController _note = TextEditingController(
    text: widget.session.note ?? '',
  );
  late String? _taskId = widget.session.taskId;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final NavigatorState navigator = Navigator.of(context);
    final FocusSessionRepository repo = ref.read(
      focusSessionRepositoryProvider,
    );
    try {
      final String note = _note.text.trim();
      await repo.assignTask(widget.session.id, _taskId);
      await repo.setNote(widget.session.id, note.isEmpty ? null : note);
      if (navigator.mounted) navigator.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('没能保存：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TodoTask> tasks =
        ref.watch(pendingTasksProvider).valueOrNull ?? const <TodoTask>[];
    final Duration used = Duration(seconds: widget.session.actualSeconds);
    final bool finished = widget.session.completed;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            finished ? '这一段走满了' : '这一段记下了',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.session.kind.label} · 实际 ${formatDuration(used)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: tasks.any((TodoTask t) => t.id == _taskId)
                ? _taskId
                : null,
            decoration: const InputDecoration(
              labelText: '挂到任务',
              border: OutlineInputBorder(),
            ),
            hint: const Text('不挂任务'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('不挂任务')),
              for (final TodoTask task in tasks)
                DropdownMenuItem<String?>(
                  value: task.id,
                  child: Text(task.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy
                ? null
                : (String? value) => setState(() => _taskId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '记一笔（可选）',
              hintText: '这一段做了什么',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (widget.onStartNext != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _save();
                            await widget.onStartNext!();
                          },
                    child: const Text('接着下一段'),
                  ),
                ),
              if (widget.onStartNext != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
