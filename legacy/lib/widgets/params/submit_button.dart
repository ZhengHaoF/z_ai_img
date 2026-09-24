import 'package:flutter/material.dart';

/// 共享的「主操作按钮 + 取消」组件，generate / edit 页面共用。
///
/// 页面负责提供 [onPressed]（其中包含提示词非空校验与分发逻辑），
/// 组件只负责呈现加载态、未配置 Key 的禁用态与取消按钮。
class SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool hasApiKey;
  final String idleLabel;
  final String loadingLabel;
  final String noApiKeyLabel;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.hasApiKey,
    required this.idleLabel,
    required this.loadingLabel,
    required this.noApiKeyLabel,
    required this.icon,
    required this.onPressed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : (hasApiKey ? onPressed : null),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(
              isLoading
                  ? loadingLabel
                  : (hasApiKey ? idleLabel : noApiKeyLabel),
            ),
          ),
        ),
        if (isLoading) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text('取消'),
          ),
        ],
      ],
    );
  }
}
