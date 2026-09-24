import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';

/// 共享的「高级设置 - 模型」下拉卡片，generate / edit 页面共用。
/// 模型列表来自当前 API Profile（自定义 `models`），为空时回退到
/// [ApiConfig.generateModels] / [ApiConfig.editModels]。
class ModelSelector extends ConsumerWidget {
  final ApiProfile profile;
  final bool isLoading;
  final List<String> models;
  final String label;

  const ModelSelector({
    super.key,
    required this.profile,
    required this.isLoading,
    required this.models,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    // 优先使用调用方列表；并入 defaultModel 与 profile.models，保证下拉值合法。
    final items = <String>{
      ...models,
      ...profile.models,
      if (profile.defaultModel.isNotEmpty) profile.defaultModel,
    }.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('高级设置', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: profile.defaultModel,
              decoration: InputDecoration(
                labelText: label,
                helperText: profile.models.isEmpty
                    ? '在设置中可自定义模型列表'
                    : '来自当前配置的自定义模型',
              ),
              items: items
                  .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                  .toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        settingsNotifier.updateProfile(
                          profile.copyWith(defaultModel: value),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
