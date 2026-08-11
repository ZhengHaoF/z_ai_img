import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';

/// 共享的「画布尺寸 + 生成数量」选择卡片，generate / edit 页面共用。
/// 内部直接更新当前激活的 API Profile，消除两页 >70% 的重复代码。
class SizeAndCountSelector extends ConsumerWidget {
  final ApiProfile profile;
  final bool isLoading;
  final bool showAdvanced;
  final VoidCallback onToggleAdvanced;

  const SizeAndCountSelector({
    super.key,
    required this.profile,
    required this.isLoading,
    required this.showAdvanced,
    required this.onToggleAdvanced,
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
            TextButton.icon(
              onPressed: onToggleAdvanced,
              icon: Icon(showAdvanced ? Icons.expand_less : Icons.expand_more),
              label: Text(showAdvanced ? '收起设置' : '更多设置'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('画布尺寸'),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: profile.defaultSize,
                        isExpanded: true,
                        items: ApiConfig.imageSizes
                            .map((size) => DropdownMenuItem(value: size, child: Text(size)))
                            .toList(),
                        onChanged: isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  settingsNotifier.updateProfile(
                                    profile.copyWith(defaultSize: value),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('生成数量'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: isLoading || profile.defaultCount <= ApiConfig.minGenerateCount
                                ? null
                                : () {
                                    settingsNotifier.updateProfile(
                                      profile.copyWith(
                                        defaultCount: profile.defaultCount - 1,
                                      ),
                                    );
                                  },
                            child: const Icon(Icons.remove, size: 20),
                          ),
                          Text(
                            '${profile.defaultCount}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          InkWell(
                            onTap: isLoading || profile.defaultCount >= ApiConfig.maxGenerateCount
                                ? null
                                : () {
                                    settingsNotifier.updateProfile(
                                      profile.copyWith(
                                        defaultCount: profile.defaultCount + 1,
                                      ),
                                    );
                                  },
                            child: const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
