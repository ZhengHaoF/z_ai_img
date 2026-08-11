import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/settings/api_config_section.dart';
import '../../widgets/settings/appearance_section.dart';
import '../../widgets/settings/tray_section.dart';
import '../../widgets/settings/data_section.dart';
import '../../widgets/settings/about_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ApiConfigSection(),
          const SizedBox(height: 16),
          const AppearanceSection(),
          const SizedBox(height: 16),
          if (settings.isTraySupported) ...[
            const TraySection(),
            const SizedBox(height: 16),
          ],
          const DataSection(),
          const SizedBox(height: 16),
          const AboutSection(),
        ],
      ),
    );
  }
}
