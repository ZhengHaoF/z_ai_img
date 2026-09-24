import 'package:flutter/material.dart';

/// 共享的提示词输入框：标题 + 多行 TextField + 即时清除按钮。
/// generate / edit 页面共用，避免重复实现「标题 + 清除按钮三态」逻辑。
class PromptField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String title;
  final String hintText;
  final int maxLength;

  const PromptField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.title,
    required this.hintText,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // 用 ValueListenableBuilder 监听输入框文本，确保清除按钮在打字时即时显示/隐藏，
        // 而不是依赖仅生成后才赋值的 state.prompt（原逻辑导致清除按钮三态错乱）。
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 5,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: hintText,
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: controller.clear,
                      )
                    : null,
              ),
              enabled: enabled,
            );
          },
        ),
      ],
    );
  }
}
