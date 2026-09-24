import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onCopy;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 14),
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              iconSize: 18,
              color: theme.colorScheme.onErrorContainer,
              tooltip: '复制错误信息',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              iconSize: 18,
              color: theme.colorScheme.onErrorContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
