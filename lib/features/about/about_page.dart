import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/license_text.dart';
import '../../core/theme/app_theme.dart';

/// 关于页：版本、开源许可、捐赠入口。
///
/// 这里是「这个应用到底会不会偷我的数据」最该说清楚的一页，所以
/// 文字按事实写，不用营销腔。
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  static const String _copyright = '© 2026 Now Todo contributors · MIT License';

  late final Future<PackageInfo?> _info = _loadInfo();

  /// 读不到版本信息不该让关于页崩掉——桌面测试环境里没有平台通道。
  Future<PackageInfo?> _loadInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
  }

  Future<void> _open(String url) async {
    final Uri? uri = Uri.tryParse(url);
    bool opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Object {
        opened = false;
      }
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('没能打开链接。')));
  }

  void _showMitLicense() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('MIT License'),
        content: const SingleChildScrollView(
          child: SelectableText(mitLicenseText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    // iOS 上不展示外部支付/捐赠链接：App Store 审核对应用内的外部
    // 支付入口有额外要求。PRD 里也写了这一条。
    //
    // 当前首版只发 Android（见 docs/PRD.md 末尾「范围变更记录」），
    // 这个分支跑不到；保留它是为了让「恢复 iOS」是一次配置变更而不是一次
    // 代码重写——去掉它，将来重新加回 iOS 时很容易忘了这条审核约束。
    final bool isIOS = theme.platform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: FutureBuilder<PackageInfo?>(
        future: _info,
        builder: (BuildContext context, AsyncSnapshot<PackageInfo?> snapshot) {
          final PackageInfo? info = snapshot.data;
          final String version = info == null
              ? '版本信息不可用'
              : '版本 ${info.version} (${info.buildNumber})';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTheme.contentMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    version,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '一个离线的待办应用。所有任务只保存在这台设备上，'
                    '没有账号，没有云端同步，核心功能不需要网络权限。'
                    '换个设备要迁移数据，只能靠你自己导出再导入。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Divider(height: 40),

                  const _SectionTitle(text: '开源许可'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('MIT License'),
                    subtitle: Text(_copyright, style: TextStyle(color: muted)),
                    onTap: _showMitLicense,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('第三方开源许可'),
                    subtitle: Text(
                      '应用里用到的每个开源包各自的许可证。',
                      style: TextStyle(color: muted),
                    ),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: info?.version,
                      applicationLegalese: _copyright,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.code),
                    title: const Text('源代码'),
                    subtitle: Text(
                      AppConstants.repositoryUrl,
                      style: TextStyle(color: muted),
                    ),
                    onTap: () => _open(AppConstants.repositoryUrl),
                  ),
                  const Divider(height: 40),

                  const _SectionTitle(text: '捐赠'),
                  Text(
                    '这个应用完全免费，没有任何付费功能，也不会因为捐赠'
                    '而解锁什么。服务器、商店开发者账号这些开销由维护者自己承担；'
                    '如果你觉得它有用，愿意分担一点，可以从下面的入口捐赠。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (isIOS)
                    Text(
                      '因为 App Store 的审核要求，iOS 版本不提供应用内的'
                      '捐赠入口。仓库主页里有捐赠说明，你可以在那里找到。',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    )
                  else if (AppConstants.donationUrl.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.favorite_border, size: 18),
                        label: const Text('前往捐赠'),
                        onPressed: () => _open(AppConstants.donationUrl),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
