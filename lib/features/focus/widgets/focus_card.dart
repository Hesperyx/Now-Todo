/// 专注子系统里几张卡片共同的外壳。
///
/// 抽出来是因为统计页与徽章页的卡片长得一样：一个标题（可带副标题）、
/// 右边可放一个切换控件、下面是内容。两处各写一份的话，改一次间距就要
/// 记得改两次——而且总会有一次忘掉。
library;

import 'package:flutter/material.dart';

/// 标题 + 可选副标题 + 可选右上角控件 + 内容。
class FocusCard extends StatelessWidget {
  const FocusCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// 卡片标题。
  final String title;

  /// 标题下的一句说明。
  final String? subtitle;

  /// 标题右边的东西，一般是分档切换。
  final Widget? trailing;

  /// 卡片内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
