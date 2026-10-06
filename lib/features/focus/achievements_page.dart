/// 成就徽章页。
///
/// 这里不读任何「解锁记录」表——根本就没有这种表。14 枚徽章的解锁状态
/// 每次都从 `focus_sessions` 现算（口径在 `lib/core/focus/achievements.dart`），
/// 所以改了判定规则之后，历史状态自己就跟着变了，不存在「已解锁但新规则
/// 说不该解锁」这种要写迁移才能修的矛盾。
///
/// 代价是每次进页面要读全部记录：几百到几千条在内存里跑一遍是毫秒级，
/// 换掉的是一张永远可能过期的表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/focus/achievements.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/focus_card.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AchievementBoard> board = ref.watch(achievementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('徽章')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: SafeArea(
            child: board.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stack) => _BoardError(
                message: '$error',
                onRetry: () => ref.invalidate(achievementsProvider),
              ),
              data: (AchievementBoard data) =>
                  data.isEmpty ? const _BoardEmpty() : _BoardList(board: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({required this.board});

  final AchievementBoard board;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AchievementProgress> progress = board.progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        FocusCard(
          title: '已解锁 ${board.unlocked} / ${board.total}',
          subtitle: '解锁状态由专注记录实时算出来，没有单独存的解锁记录。',
          child: LinearProgressIndicator(
            value: board.total == 0 ? 0 : board.unlocked / board.total,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        // 顺序就是 `kAchievements` 的顺序（从易到难）：不分组是因为
        // 「这条路有多长」本身就是这页想说的事。
        for (final AchievementProgress item in progress) ...<Widget>[
          _BadgeTile(progress: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// 一枚徽章：解锁与否、达成条件、没到时的进度。
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool unlocked = progress.unlocked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: unlocked ? scheme.primary : scheme.onSurfaceVariant,
              semanticLabel: unlocked ? '已解锁' : '还没解锁',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          progress.achievement.title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        progress.progressText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progress.achievement.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!unlocked) ...<Widget>[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '还差 ${progress.remaining} ${progress.achievement.unit.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty();

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
              Icons.emoji_events_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('还没有专注记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '徽章是从专注记录里算出来的——先完成一段专注，第一枚就到了。',
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

class _BoardError extends StatelessWidget {
  const _BoardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('徽章读不出来了', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
