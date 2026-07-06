import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/system_tray.dart';
import '../../utils/validators.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _profileApiKeyController = TextEditingController();
  final _profileBaseUrlController = TextEditingController();
  final _profileChatBaseUrlController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _syncProfileControllers(settings.activeProfile());
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _profileApiKeyController.dispose();
    _profileBaseUrlController.dispose();
    _profileChatBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = settings.activeProfile();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API 配置集
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'API 配置集',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                      // 配置名称
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

                      // API Key
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

                      // Base URL
                      TextFormField(
                        controller: _profileBaseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'https://jeniya.cn',
                        ),
                        validator: Validators.validateBaseUrl,
                      ),

                      const SizedBox(height: 16),

                      // Chat Base URL
                      TextFormField(
                        controller: _profileChatBaseUrlController,
                        decoration: const InputDecoration(
                          labelText: '对话 Base URL（可选）',
                          hintText: '留空则自动从 Base URL 推导',
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '默认生图参数',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 默认模型
                      DropdownButtonFormField<String>(
                        value: profile.defaultModel,
                        decoration: const InputDecoration(labelText: '默认模型'),
                        items: ApiConfig.generateModels.map((model) {
                          return DropdownMenuItem(value: model, child: Text(model));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            final updated = profile.copyWith(defaultModel: value);
                            notifier.updateProfile(updated);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // 默认尺寸
                      DropdownButtonFormField<String>(
                        value: profile.defaultSize,
                        decoration: const InputDecoration(labelText: '默认尺寸'),
                        items: ApiConfig.imageSizes.map((size) {
                          return DropdownMenuItem(value: size, child: Text(size));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            final updated = profile.copyWith(defaultSize: value);
                            notifier.updateProfile(updated);
                          }
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
                            onPressed: profile.defaultCount <= ApiConfig.minGenerateCount
                                ? null
                                : () {
                                    final updated = profile.copyWith(defaultCount: profile.defaultCount - 1);
                                    notifier.updateProfile(updated);
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
                                    final updated = profile.copyWith(defaultCount: profile.defaultCount + 1);
                                    notifier.updateProfile(updated);
                                  },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '默认对话参数',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 默认对话模型
                      DropdownButtonFormField<String>(
                        value: profile.defaultChatModel,
                        decoration: const InputDecoration(labelText: '默认对话模型'),
                        items: ApiConfig.chatModels.map((model) {
                          return DropdownMenuItem(value: model, child: Text(model));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            final updated = profile.copyWith(defaultChatModel: value);
                            notifier.updateProfile(updated);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // 默认温度
                      Row(
                        children: [
                          const Expanded(
                            child: Text('默认温度'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: profile.defaultTemperature <= 0
                                ? null
                                : () {
                                    final updated = profile.copyWith(defaultTemperature: (profile.defaultTemperature - 0.1).clamp(0.0, 2.0));
                                    notifier.updateProfile(updated);
                                  },
                          ),
                          Text(
                            profile.defaultTemperature.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: profile.defaultTemperature >= 2
                                ? null
                                : () {
                                    final updated = profile.copyWith(defaultTemperature: (profile.defaultTemperature + 0.1).clamp(0.0, 2.0));
                                    notifier.updateProfile(updated);
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

            // 托盘图标设置 (仅 Windows/macOS/Linux 显示)
            if (settings.isTraySupported)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '托盘图标',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 托盘图标开关
                      SwitchListTile(
                        title: const Text('显示托盘图标'),
                        subtitle: const Text('在系统托盘显示应用图标'),
                        value: settings.showTrayIcon,
                        onChanged: (value) async {
                          notifier.setShowTrayIcon(value);
                          // 初始化或销毁托盘
                          if (value) {
                            await SystemTrayManager.instance.initialize(
                              onOpenWindow: () {
                                debugPrint('托盘: 打开主窗口');
                              },
                              onCancelTask: () {
                                debugPrint('托盘: 取消任务');
                              },
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
              ),

            if (settings.isTraySupported)
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
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.chat_outlined),
                      title: const Text('清空对话历史'),
                      subtitle: const Text('清除所有对话记录'),
                      contentPadding: EdgeInsets.zero,
                      onTap: _showClearChatDialog,
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

  void _syncProfileControllers(ApiProfile? profile) {
    if (profile == null) {
      _profileNameController.text = '';
      _profileApiKeyController.text = '';
      _profileBaseUrlController.text = ApiConfig.defaultBaseUrl;
      _profileChatBaseUrlController.text = '';
      return;
    }
    _profileNameController.text = profile.name;
    _profileApiKeyController.text = profile.apiKey;
    _profileBaseUrlController.text = profile.baseUrl;
    _profileChatBaseUrlController.text = profile.chatBaseUrl ?? '';
  }

  void _saveProfile(SettingsNotifier notifier, ApiProfile profile) {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = profile.copyWith(
        name: _profileNameController.text.trim(),
        apiKey: _profileApiKeyController.text,
        baseUrl: _profileBaseUrlController.text.trim(),
        chatBaseUrl: _profileChatBaseUrlController.text.trim().isEmpty
            ? null
            : _profileChatBaseUrlController.text.trim(),
      );
      notifier.updateProfile(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API 配置已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddProfileDialog(SettingsNotifier notifier) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增 API 配置'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '配置名称',
            hintText: '例如：备用配置',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await notifier.addProfile(name);
              if (mounted) {
                final settings = ref.read(settingsProvider);
                _syncProfileControllers(settings.activeProfile());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已新增配置'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showRemoveProfileDialog(SettingsNotifier notifier, ApiProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定要删除「${profile.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await notifier.removeProfile(profile.id);
              if (mounted) {
                final settings = ref.read(settingsProvider);
                _syncProfileControllers(settings.activeProfile());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('配置已删除'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
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
              final settings = ref.read(settingsProvider);
              _syncProfileControllers(settings.activeProfile());
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

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空所有对话记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('对话已清空'),
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
