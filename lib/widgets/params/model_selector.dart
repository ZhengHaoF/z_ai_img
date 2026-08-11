import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';

/// 共享的「高级设置 - 模型」下拉卡片，generate / edit 页面共用。
/// 列表内容由调用方传入（生成用 [ApiConfig.generateModels]，编辑用 [ApiConfig.editModels]）。
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
              decoration: InputDecoration(labelText: label),
              items: models
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
