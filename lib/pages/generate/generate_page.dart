import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/generate_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/image_utils.dart';
import '../preview/image_preview_page.dart';

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  bool _showAdvanced = false;

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
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
                : (settings.hasApiKey ? () => notifier.generate() : null),
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

  Widget _buildResults(GenerateState state, GenerateNotifier notifier) {
    if (state.status == GenerateStatus.idle && !state.hasImages) {
      return _buildEmptyState();
    }

    if (state.status == GenerateStatus.error) {
      return _buildErrorState(state.errorMessage);
    }

    if (state.hasImages) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '生成结果',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: notifier.clearImages,
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
        ],
      );
    }

    return const SizedBox.shrink();
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? '发生错误',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
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
