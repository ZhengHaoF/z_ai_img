import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/generate_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/image_utils.dart';
import '../../utils/foreground_service.dart';  // 新增：生命周期感知
import '../preview/image_preview_page.dart';

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage>
    with WidgetsBindingObserver {  // 监听 App 生命周期
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  bool _showAdvanced = false;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final genState = ref.read(generateProvider);

    if (state == AppLifecycleState.paused) {
      // App 进入后台，如果有正在进行的生成，显示提示
      if (genState.isLoading) {
        // 切后台时更新通知，让用户知道任务还在进行
        ForegroundService.updateGeneratingNotification(
          title: '⏸️ 图片生成中',
          body: '生成仍在继续，切回 App 查看结果',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      // App 回到前台，如果之前在生成但现在失败了，给出提示
      if (genState.status == GenerateStatus.error) {
        final errorMsg = genState.errorMessage ?? '';
        if (errorMsg.contains('连接') || errorMsg.contains('timeout') || errorMsg.contains('Socket')) {
          // 由于切后台导致连接断开，给出更明确的提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ 由于切后台，生成任务可能已中断。是否重新尝试？'),
              action: SnackBarAction(
                label: '重试',
                onPressed: () {
                  final notifier = ref.read(generateProvider.notifier);
                  notifier.generate();
                },
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(generateProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 进度条
            if (state.isLoading)
              LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                backgroundColor: Colors.transparent,
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 提示词输入
                    _buildPromptInput(state, notifier),

                    const SizedBox(height: 16),

                    // 基础参数
                    _buildBasicParams(state, notifier),

                    // 高级参数
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      _buildAdvancedParams(state, notifier),
                    ],

                    const SizedBox(height: 16),

                    // 生成按钮
                    _buildGenerateButton(state, notifier, settings),

                    const SizedBox(height: 16),

                    // 结果展示
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
            suffixIcon: state.prompt.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _promptController.clear();
                      notifier.updatePrompt('');
                    },
                  )
                : null,
          ),
          onChanged: notifier.updatePrompt,
          enabled: !state.isLoading,
        ),
      ],
    );
  }

  Widget _buildBasicParams(GenerateState state, GenerateNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 更多设置按钮
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
                        value: state.size,
                        isExpanded: true,
                        items: ApiConfig.imageSizes.map((size) {
                          return DropdownMenuItem(value: size, child: Text(size));
                        }).toList(),
                        onChanged: state.isLoading
                            ? null
                            : (value) {
                                if (value != null) notifier.updateSize(value);
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
                            onTap: state.isLoading || state.n <= ApiConfig.minGenerateCount
                                ? null
                                : () => notifier.updateN(state.n - 1),
                            child: const Icon(Icons.remove, size: 20),
                          ),
                          Text(
                            '${state.n}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          InkWell(
                            onTap: state.isLoading || state.n >= ApiConfig.maxGenerateCount
                                ? null
                                : () => notifier.updateN(state.n + 1),
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

  Widget _buildAdvancedParams(GenerateState state, GenerateNotifier notifier) {
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

            // 模型选择
            DropdownButtonFormField<String>(
              value: state.model,
              decoration: const InputDecoration(labelText: '模型'),
              items: ApiConfig.generateModels.map((model) {
                return DropdownMenuItem(value: model, child: Text(model));
              }).toList(),
              onChanged: state.isLoading
                  ? null
                  : (value) {
                      if (value != null) notifier.updateModel(value);
                    },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: state.format,
                    decoration: const InputDecoration(labelText: '格式'),
                    items: ApiConfig.imageFormats.map((format) {
                      return DropdownMenuItem(value: format, child: Text(format));
                    }).toList(),
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            if (value != null) notifier.updateFormat(value);
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: state.quality,
                    decoration: const InputDecoration(labelText: '画质'),
                    items: ApiConfig.qualityOptions.map((quality) {
                      return DropdownMenuItem(value: quality, child: Text(quality));
                    }).toList(),
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            if (value != null) notifier.updateQuality(value);
                          },
                  ),
                ),
              ],
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
                    ? () => _onGeneratePressed(context, notifier, settings)
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
            onPressed: notifier.cancel,
            child: const Text('取消'),
          ),
        ],
      ],
    );
  }

  /// 生成按钮点击处理（包含悬浮窗权限检查）
  Future<void> _onGeneratePressed(
    BuildContext context,
    GenerateNotifier notifier,
    SettingsState settings,
  ) async {
    await notifier.generate();
  }

  Widget _buildResults(GenerateState state, GenerateNotifier notifier) {
    // 没有任何图片且空闲 → 显示空状态引导
    if (!state.hasImages && state.status == GenerateStatus.idle) {
      return _buildEmptyState();
    }

    // 没有任何图片但有错误 → 只显示错误
    if (!state.hasImages && state.status == GenerateStatus.error) {
      return _buildErrorState(state.errorMessage);
    }

    // 有图片 → 始终显示图片网格
    final children = <Widget>[];

    // 在图片上方始终显示错误横幅（如果有错误）
    if (state.status == GenerateStatus.error) {
      children.add(_buildErrorState(state.errorMessage));
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
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: state.images.length,
        itemBuilder: (context, index) {
          final image = state.images[index];
          return GestureDetector(
            onTap: () => _openPreview(index, state.images),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    image.imageData,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.broken_image,
                          color: Theme.of(context).colorScheme.error,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      icon: const Icon(Icons.save_alt),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _saveImage(image.imageData),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.image_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '输入描述，开始生成你的 AI 图片',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    final errorText = message ?? '发生错误';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.copy,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            tooltip: '复制错误信息',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: errorText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制到剪贴板'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清空所有已生成的图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(generateProvider.notifier).clearImages();
    }
  }

  Future<void> _saveImage(Uint8List imageData) async {
    final success = await ImageUtils.saveImage(imageData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '保存成功' : '保存失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
