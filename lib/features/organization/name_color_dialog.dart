import 'package:flutter/material.dart';

import '../../core/theme/entity_palette.dart';

/// 编辑结果的形状。
typedef NameColorResult = ({String name, int? color});

/// 「名字 + 颜色」的编辑弹窗，清单和标签共用。
///
/// 两个页面的编辑界面完全一样（一个文本框加一排色块），差别只在标题和
/// 校验文案。复制两份的代价不是多写几十行，而是以后改一处忘一处——
/// 那时候用户会看到同一种操作在两个页面里有两种手感。
///
/// 返回 `null` 表示用户取消了。取消不是「什么都没发生」：色块是即时
/// 预览的，所以不返回结果就等于把预览丢掉，这正是取消该有的样子。
Future<NameColorResult?> showNameColorDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String emptyMessage,
  String initialName = '',
  int? initialColor,
}) {
  return showDialog<NameColorResult>(
    context: context,
    builder: (BuildContext context) => _NameColorDialog(
      title: title,
      hint: hint,
      emptyMessage: emptyMessage,
      initialName: initialName,
      initialColor: initialColor,
    ),
  );
}

class _NameColorDialog extends StatefulWidget {
  const _NameColorDialog({
    required this.title,
    required this.hint,
    required this.emptyMessage,
    required this.initialName,
    required this.initialColor,
  });

  final String title;
  final String hint;
  final String emptyMessage;
  final String initialName;
  final int? initialColor;

  @override
  State<_NameColorDialog> createState() => _NameColorDialogState();
}

class _NameColorDialogState extends State<_NameColorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late int? _color = widget.initialColor;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final bool empty = _name.text.trim().isEmpty;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              // 50 与 `tags.name` 的 `withLength(max: 50)` 对齐。
              // 让用户在输入时被拦住，比保存时抛一个数据库异常好。
              maxLength: 50,
              decoration: InputDecoration(
                labelText: '名称',
                hintText: widget.hint,
                errorText: empty ? widget.emptyMessage : null,
                counterText: '',
              ),
              // 只为了让「空」这个错误提示随输入消失，不改变任何业务值。
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text('颜色', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _Palette(
              selected: _color,
              onSelected: (int? value) => setState(() => _color = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        // 名字为空时置灰而不是弹一句错：错误提示就在输入框下面，
        // 再弹一次是重复说话。
        FilledButton(
          onPressed: empty ? null : _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _Swatch(
          color: null,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final Color color in EntityPalette.colors)
          _Swatch(
            color: color,
            selected: selected == color.toARGB32(),
            onTap: () => onSelected(color.toARGB32()),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '不选也行',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  /// `null` 是「不选颜色」，画成一个空心圈。
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? fill = color;

    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected && fill != null
              ? Icon(Icons.check, size: 18, color: EntityPalette.onColor(fill))
              : null,
        ),
      ),
    );
  }
}
