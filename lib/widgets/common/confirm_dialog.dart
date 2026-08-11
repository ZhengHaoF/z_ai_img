import 'package:flutter/material.dart';

/// 统一的确认对话框。
///
/// 返回 `true` 表示确认，`false` 或 `null` 表示取消 / 关闭。
/// [isDestructive] 为 true 时确认按钮使用主题的 error 色，用于删除、清空等不可逆操作。
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}

/// 统一的单行文本输入对话框。
///
/// 返回已 trim 的非空文本；用户取消或关闭时返回 `null`。
/// 内部创建的 [TextEditingController] 会在对话框关闭后释放，调用方无需处理。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? labelText,
  String? hintText,
  String initialValue = '',
  String confirmText = '确定',
  String cancelText = '取消',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit(String raw) {
          final text = raw.trim();
          if (text.isEmpty) return;
          Navigator.of(dialogContext).pop(text);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
            ),
            onSubmitted: submit,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelText),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final isEmpty = value.text.trim().isEmpty;
                return TextButton(
                  onPressed: isEmpty ? null : () => submit(value.text),
                  child: Text(confirmText),
                );
              },
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
