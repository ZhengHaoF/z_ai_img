import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../utils/system_tray.dart';

/// 设置页「托盘图标」分区，仅在不支持系统托盘的平台由调用方决定是否渲染。
class TraySection extends ConsumerWidget {
  const TraySection({super.key});

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
              '托盘图标',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('显示托盘图标'),
              subtitle: const Text('在系统托盘显示应用图标'),
              value: settings.showTrayIcon,
              onChanged: (value) async {
                notifier.setShowTrayIcon(value);
                if (value) {
                  await SystemTrayManager.instance.initialize(
                    onOpenWindow: () => debugPrint('托盘: 打开主窗口'),
                    onCancelTask: () => debugPrint('托盘: 取消任务'),
                    onQuit: () {
                      debugPrint('托盘: 退出应用');
                      exit(0);
                    },
                  );
                } else {
                  await SystemTrayManager.instance.dispose();
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
