import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/image_utils.dart';

/// 统一的反馈语义类型，避免各页面硬编码 Colors.green / Colors.red，
/// 保证浅色与深色主题下的对比度都由 ColorScheme 决定。
enum FeedbackKind { info, success, error }

/// 全局统一的 SnackBar 呈现。
///
/// 会先关闭当前 SnackBar，避免连续操作时排队堆积。
void showAppSnackBar(
  BuildContext context,
  String message, {
  FeedbackKind kind = FeedbackKind.info,
  Duration duration = const Duration(seconds: 2),
}) {
  final scheme = Theme.of(context).colorScheme;

  final (Color? background, Color? foreground) = switch (kind) {
    FeedbackKind.info => (null, null),
    FeedbackKind.success => (scheme.primary, scheme.onPrimary),
    FeedbackKind.error => (scheme.error, scheme.onError),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: foreground == null ? null : TextStyle(color: foreground),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: background,
      ),
    );
}

/// 保存图片并给出统一反馈。异常一律降级为「保存失败」，不向上抛。
Future<void> saveImageWithFeedback(
  BuildContext context,
  Uint8List imageData, {
  String? fileName,
}) async {
  bool success;
  try {
    success = await ImageUtils.saveImage(imageData, fileName: fileName);
  } catch (_) {
    success = false;
  }

  if (!context.mounted) return;
  showAppSnackBar(
    context,
    success ? '已保存到本地' : '保存失败',
    kind: success ? FeedbackKind.success : FeedbackKind.error,
  );
}

/// 复制文本到剪贴板并给出统一反馈。
Future<void> copyTextWithFeedback(
  BuildContext context,
  String text, {
  String message = '已复制到剪贴板',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showAppSnackBar(context, message, duration: const Duration(seconds: 1));
}
