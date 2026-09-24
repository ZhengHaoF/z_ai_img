import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

/// 设置页「外观」分区：深色模式开关。
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '外观',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('深色模式'),
              value: settings.isDarkMode,
              onChanged: notifier.setDarkMode,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
