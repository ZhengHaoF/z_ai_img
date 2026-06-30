import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';
import '../../utils/validators.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API 配置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API 配置',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // API Key
                    TextFormField(
                      controller: _apiKeyController,
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
                      onSaved: (value) {
                        if (value != null) {
                          notifier.setApiKey(value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Base URL
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://jeniya.cn',
                      ),
                      validator: Validators.validateBaseUrl,
                      onSaved: (value) {
                        if (value != null) {
                          notifier.setBaseUrl(value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveApiConfig,
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 默认参数
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '默认参数',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 默认模型
                    DropdownButtonFormField<String>(
                      value: settings.defaultModel,
                      decoration: const InputDecoration(labelText: '默认模型'),
                      items: ApiConfig.generateModels.map((model) {
                        return DropdownMenuItem(value: model, child: Text(model));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) notifier.setDefaultModel(value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 默认尺寸
                    DropdownButtonFormField<String>(
                      value: settings.defaultSize,
                      decoration: const InputDecoration(labelText: '默认尺寸'),
                      items: ApiConfig.imageSizes.map((size) {
                        return DropdownMenuItem(value: size, child: Text(size));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) notifier.setDefaultSize(value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 默认数量
                    Row(
                      children: [
                        const Expanded(
                          child: Text('默认生成数量'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: settings.defaultCount <= ApiConfig.minGenerateCount
                              ? null
                              : () => notifier.setDefaultCount(settings.defaultCount - 1),
                        ),
                        Text(
                          '${settings.defaultCount}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: settings.defaultCount >= ApiConfig.maxGenerateCount
                              ? null
                              : () => notifier.setDefaultCount(settings.defaultCount + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 主题设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '外观',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
            ),

            const SizedBox(height: 16),

            // 清除缓存
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '数据管理',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('清除所有设置'),
                      subtitle: const Text('重置所有设置到默认值'),
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _showClearSettingsDialog(notifier),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 关于
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '关于',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('AI 图片生成工具'),
                      subtitle: Text('版本 1.0.0'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveApiConfig() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API 配置已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showClearSettingsDialog(SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除设置'),
        content: const Text('确定要清除所有设置吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              _apiKeyController.clear();
              _baseUrlController.text = ApiConfig.defaultBaseUrl;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('设置已清除'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
