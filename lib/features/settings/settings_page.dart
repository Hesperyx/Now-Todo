import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/models/entities.dart';
import '../../core/models/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';

/// 设置页。
///
/// 刻意只放「真的会生效」的开关。提醒开关要等 `ReminderScheduler`
/// （见 `docs/MILESTONES.md` M5）落地才加——现在放一个写着「通知」
/// 却什么都不做的开关，比没有这个开关更糟。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences preferences =
        ref.watch(preferencesProvider).valueOrNull ?? const AppPreferences();

    Future<void> write({
      ThemeModeSetting? themeMode,
      DefaultView? defaultView,
    }) async {
      try {
        await ref
            .read(settingsRepositoryProvider)
            .update(themeMode: themeMode, defaultView: defaultView);
      } on Object catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('没能保存设置：$error')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              const _SectionHeader(text: '外观'),
              _SettingBlock(
                title: '主题',
                subtitle: '「跟随系统」会随系统深浅色切换。',
                child: SegmentedButton<ThemeModeSetting>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<ThemeModeSetting>>[
                    for (final ThemeModeSetting mode in ThemeModeSetting.values)
                      ButtonSegment<ThemeModeSetting>(
                        value: mode,
                        label: Text(mode.label),
                      ),
                  ],
                  selected: <ThemeModeSetting>{preferences.themeMode},
                  onSelectionChanged: (Set<ThemeModeSetting> selection) =>
                      write(themeMode: selection.first),
                ),
              ),
              const Divider(height: 32),
              const _SectionHeader(text: '启动'),
              _SettingBlock(
                title: '默认视图',
                subtitle: '打开应用时先看哪个视图。切换视图不会改这里。',
                child: SegmentedButton<DefaultView>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<DefaultView>>[
                    for (final DefaultView view in DefaultView.values)
                      ButtonSegment<DefaultView>(
                        value: view,
                        label: Text(view.label),
                      ),
                  ],
                  selected: <DefaultView>{preferences.defaultView},
                  onSelectionChanged: (Set<DefaultView> selection) =>
                      write(defaultView: selection.first),
                ),
              ),
              const Divider(height: 32),
              const _SectionHeader(text: '其他'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本、开源许可、捐赠'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.about),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? description = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.bodyLarge),
          if (description != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ),
    );
  }
}
