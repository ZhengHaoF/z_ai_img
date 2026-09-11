import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';
import '../../utils/validators.dart';
import '../common/confirm_dialog.dart';
import '../common/feedback.dart';

/// 设置页「API 配置集」分区（含新增 / 删除 / 保存配置对话框）。
///
/// 从 [SettingsPage] 抽取为独立 StatefulWidget，自带 Form 与编辑控制器，
/// 使设置页 `build()` 不再承担数百行内联 UI。
///
/// 通过监听 [settingsProvider] 中「可编辑字段」的签名变化来同步文本框，
/// 既能覆盖切换配置 / 新增 / 删除 / 清除设置等场景，又不会在用户正在输入框打字时
/// 误覆盖（打字只改控制器、不改 Profile 状态，签名不变）。
class ApiConfigSection extends ConsumerStatefulWidget {
  const ApiConfigSection({super.key});

  @override
  ConsumerState<ApiConfigSection> createState() => _ApiConfigSectionState();
}

class _ApiConfigSectionState extends ConsumerState<ApiConfigSection> {
  final _formKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _profileApiKeyController = TextEditingController();
  final _profileBaseUrlController = TextEditingController();
  bool _obscureApiKey = true;
  String? _lastSignature;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(settingsProvider).activeProfile();
    _syncProfileControllers(profile);
    _lastSignature = _editableSignature(profile);
    ref.listenManual(settingsProvider, (prev, next) {
      final sig = _editableSignature(next.activeProfile());
      if (sig != _lastSignature) {
        _lastSignature = sig;
        _syncProfileControllers(next.activeProfile());
      }
    });
  }

  String _editableSignature(ApiProfile? p) =>
      '${p?.id}::${p?.name}::${p?.apiKey}::${p?.baseUrl}';

  @override
  void dispose() {
    _profileNameController.dispose();
    _profileApiKeyController.dispose();
    _profileBaseUrlController.dispose();
    super.dispose();
  }

  void _syncProfileControllers(ApiProfile? profile) {
    if (profile == null) {
      _profileNameController.text = '';
      _profileApiKeyController.text = '';
      _profileBaseUrlController.text = ApiConfig.defaultBaseUrl;
      return;
    }
    _profileNameController.text = profile.name;
    _profileApiKeyController.text = profile.apiKey;
    _profileBaseUrlController.text = profile.baseUrl;
  }

  void _saveProfile(SettingsNotifier notifier, ApiProfile profile) {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = profile.copyWith(
        name: _profileNameController.text.trim(),
        apiKey: _profileApiKeyController.text,
        baseUrl: _profileBaseUrlController.text.trim(),
      );
      notifier.updateProfile(updated);
      showAppSnackBar(context, 'API 配置已保存', kind: FeedbackKind.success);
    }
  }

  Future<void> _showAddProfileDialog(SettingsNotifier notifier) async {
    final name = await showTextInputDialog(
      context,
      title: '新增 API 配置',
      labelText: '配置名称',
      hintText: '例如：备用配置',
    );
    if (name == null) return;

    await notifier.addProfile(name);
    if (!mounted) return;

    _syncProfileControllers(ref.read(settingsProvider).activeProfile());
    showAppSnackBar(context, '已新增配置', kind: FeedbackKind.success);
  }

  Future<void> _showRemoveProfileDialog(
    SettingsNotifier notifier,
    ApiProfile profile,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除配置',
      content: '确定要删除「${profile.name}」吗？',
      confirmText: '删除',
      isDestructive: true,
    );
    if (confirmed != true) return;

    await notifier.removeProfile(profile.id);
    if (!mounted) return;

    _syncProfileControllers(ref.read(settingsProvider).activeProfile());
    showAppSnackBar(context, '配置已删除', kind: FeedbackKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = settings.activeProfile();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'API 配置集',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddProfileDialog(notifier),
                    icon: const Icon(Icons.add),
                    tooltip: '新增配置',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (settings.apiProfiles.isEmpty)
                const Text('暂无配置，请新增')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: settings.apiProfiles.map((item) {
                    final isActive = profile != null && profile.id == item.id;
                    return ChoiceChip(
                      label: Text(item.name),
                      selected: isActive,
                      onSelected: (selected) {
                        if (selected) {
                          notifier.switchProfile(item.id);
                          _syncProfileControllers(item);
                        }
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              if (profile != null) ...[
                TextFormField(
                  controller: _profileNameController,
                  decoration: const InputDecoration(
                    labelText: '配置名称',
                    hintText: '例如：默认配置',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入配置名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _profileApiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: '输入你的 API Key',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureApiKey = !_obscureApiKey);
                          },
                        ),
                      ],
                    ),
                  ),
                  validator: Validators.validateApiKey,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _profileBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://jeniya.cn',
                  ),
                  validator: Validators.validateBaseUrl,
                ),
                const SizedBox(height: 16),
                const Text(
                  '默认生图参数',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: profile.defaultModel,
                  decoration: const InputDecoration(labelText: '默认模型'),
                  items: ApiConfig.generateModels
                      .map((model) =>
                          DropdownMenuItem(value: model, child: Text(model)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateProfile(profile.copyWith(defaultModel: value));
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: profile.defaultSize,
                  decoration: const InputDecoration(labelText: '默认尺寸'),
                  items: ApiConfig.imageSizes
                      .map((size) => DropdownMenuItem(value: size, child: Text(size)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateProfile(profile.copyWith(defaultSize: value));
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('默认生成数量')),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: profile.defaultCount <= ApiConfig.minGenerateCount
                          ? null
                          : () {
                              notifier.updateProfile(profile.copyWith(
                                  defaultCount: profile.defaultCount - 1));
                            },
                    ),
                    Text(
                      '${profile.defaultCount}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: profile.defaultCount >= ApiConfig.maxGenerateCount
                          ? null
                          : () {
                              notifier.updateProfile(profile.copyWith(
                                  defaultCount: profile.defaultCount + 1));
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveProfile(notifier, profile),
                        child: const Text('保存当前配置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (settings.apiProfiles.length > 1)
                      ElevatedButton(
                        onPressed: () => _showRemoveProfileDialog(notifier, profile),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('删除配置'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
