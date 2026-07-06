import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/generate_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/foreground_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/result_grid.dart';
import '../preview/image_preview_page.dart';

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage>
    with WidgetsBindingObserver {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  bool _showAdvanced = false;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promptController.dispose();
    _promptFocusNode.dispose();
    _cancelToken?.cancel('页面销毁');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final genState = ref.read(generateProvider);

    if (state == AppLifecycleState.paused) {
      if (genState.isLoading) {
        ForegroundService.updateGeneratingNotification(
          title: '⏸️ 图片生成中',
          body: '生成仍在继续，切回 App 查看结果',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      final error = genState.error;
      if (error != null && _isBackgroundInterruptedError(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ 由于切后台，生成任务可能已中断。是否重新尝试？'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                final prompt = _promptController.text.trim();
                if (prompt.isNotEmpty) {
                  _cancelToken = CancelToken();
                  ref.read(generateProvider.notifier).generateImage(
                    prompt: prompt,
                    cancelToken: _cancelToken,
                  );
                }
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _isBackgroundInterruptedError(String error) {
    final normalized = error.toLowerCase();
    return normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('socket') ||
        normalized.contains('网络') ||
        normalized.contains('连接');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(generateProvider.notifier);
    final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (state.isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPromptInput(state, notifier),
                    const SizedBox(height: 16),
                    _buildBasicParams(state, notifier, profile),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      _buildAdvancedParams(state, notifier, profile),
                    ],
                    const SizedBox(height: 16),
                    _buildGenerateButton(state, notifier, settings),
                    const SizedBox(height: 16),
                    _buildResults(state, notifier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput(GenerateState state, GenerateNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '提示词',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptController,
          focusNode: _promptFocusNode,
          maxLines: 5,
          maxLength: ApiConfig.maxPromptLength,
          decoration: InputDecoration(
            hintText: '输入描述，开始生成你的 AI 图片',
            suffixIcon: state.prompt?.isNotEmpty ?? false
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _promptController.clear();
                    },
                  )
                : null,
          ),
          enabled: !state.isLoading,
        ),
      ],
    );
  }

  Widget _buildBasicParams(GenerateState state, GenerateNotifier notifier, ApiProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
              label: Text(_showAdvanced ? '收起设置' : '更多设置'),
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
                        items: ApiConfig.imageSizes.map((size) {
                          return DropdownMenuItem(value: size, child: Text(size));
                        }).toList(),
                        onChanged: state.isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  final updated = profile.copyWith(defaultSize: value);
                                  ref.read(settingsProvider.notifier).updateProfile(updated);
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
                            onTap: state.isLoading || profile.defaultCount <= ApiConfig.minGenerateCount
                                ? null
                                : () {
                                    final updated = profile.copyWith(defaultCount: profile.defaultCount - 1);
                                    ref.read(settingsProvider.notifier).updateProfile(updated);
                                  },
                            child: const Icon(Icons.remove, size: 20),
                          ),
                          Text(
                            '${profile.defaultCount}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          InkWell(
                            onTap: state.isLoading || profile.defaultCount >= ApiConfig.maxGenerateCount
                                ? null
                                : () {
                                    final updated = profile.copyWith(defaultCount: profile.defaultCount + 1);
                                    ref.read(settingsProvider.notifier).updateProfile(updated);
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

  Widget _buildAdvancedParams(GenerateState state, GenerateNotifier notifier, ApiProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '高级设置',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: profile.defaultModel,
              decoration: const InputDecoration(labelText: '模型'),
              items: ApiConfig.generateModels.map((model) {
                return DropdownMenuItem(value: model, child: Text(model));
              }).toList(),
              onChanged: state.isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        final updated = profile.copyWith(defaultModel: value);
                        ref.read(settingsProvider.notifier).updateProfile(updated);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(
    GenerateState state,
    GenerateNotifier notifier,
    SettingsState settings,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.isLoading
                ? null
                : (settings.hasApiKey
                    ? () {
                        final prompt = _promptController.text.trim();
                        if (prompt.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请输入提示词'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _cancelToken = CancelToken();
                        notifier.generateImage(
                          prompt: prompt,
                          cancelToken: _cancelToken,
                        );
                      }
                    : null),
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              state.isLoading
                  ? 'AI 正在生成中，请稍候...'
                  : (settings.hasApiKey ? '生成图片' : '请先配置 API Key'),
            ),
          ),
        ),
        if (state.isLoading) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _cancelToken?.cancel('用户取消');
            },
            child: const Text('取消'),
          ),
        ],
      ],
    );
  }

  Widget _buildResults(GenerateState state, GenerateNotifier notifier) {
    final images = state.images;

    if (images.isEmpty) {
      if (state.isLoading) {
        return const SizedBox.shrink();
      }

      if (state.error != null) {
        return _buildErrorState(state.error);
      }

      return const EmptyState(
        icon: Icons.image_outlined,
        title: '输入描述，开始生成你的 AI 图片',
      );
    }

    final children = <Widget>[];

    if (state.error != null) {
      children.add(_buildErrorState(state.error));
      children.add(const SizedBox(height: 12));
    }

    children.addAll([
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '生成结果',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          TextButton.icon(
            onPressed: _onClearPressed,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('清除'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ResultGrid(
        images: images,
        onItemTap: (index) => _openPreview(index, images),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildErrorState(String? message) {
    final errorText = message ?? '发生错误';
    return ErrorBanner(
      message: errorText,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: errorText));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已复制到剪贴板'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _openPreview(int initialIndex, List<ImageResult> images) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagePreviewPage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _onClearPressed() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认清除',
      content: '确定要清空所有已生成的图片吗？',
    );

    if (confirmed == true && mounted) {
      ref.read(generateProvider.notifier).clearError();
    }
  }
}
