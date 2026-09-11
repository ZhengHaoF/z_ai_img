import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../common/confirm_dialog.dart';
import '../common/feedback.dart';

/// 设置页「数据管理」分区：清除所有设置。
class DataSection extends ConsumerWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据管理',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清除所有设置'),
              subtitle: const Text('重置所有设置到默认值'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: '清除设置',
                  content: '确定要清除所有设置吗？此操作不可恢复。',
                  confirmText: '清除',
                  isDestructive: true,
                );
                if (confirmed != true) return;
                await settingsNotifier.clearAll();
                if (!context.mounted) return;
                showAppSnackBar(context, '设置已清除', kind: FeedbackKind.success);
              },
            ),
          ],
        ),
      ),
    );
  }
}
