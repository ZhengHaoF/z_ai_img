import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/edit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/image_utils.dart';
import '../preview/image_preview_page.dart';

class EditPage extends ConsumerStatefulWidget {
  const EditPage({super.key});

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
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
    final state = ref.watch(editProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(editProvider.notifier);

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
                    // 图片选择区
                    _buildImageSection(state, notifier),

                    const SizedBox(height: 16),

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

                    // 编辑按钮
                    _buildEditButton(state, notifier, settings),

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

  Widget _buildImageSection(EditState state, EditNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '源图片',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择一张或多张图片进行编辑',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // 图片预览列表
            if (state.hasSourceImages) ...[
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.sourceImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              state.sourceImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: () => notifier.removeSourceImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 添加图片按钮
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: state.isLoading ? null : () => _pickImage(notifier),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('添加图片'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: state.isLoading || state.sourceImages.isEmpty
                      ? null
                      : () => notifier.clearSourceImages(),
                  icon: const Icon(Icons.clear),
                  label: const Text('清空'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 遮罩图片（可选）
            const Text(
              '遮罩图片（可选）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '指定编辑区域，仅对第一张图生效',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),

            if (state.maskImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  state.maskImage!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => notifier.setMaskImage(null),
                icon: const Icon(Icons.clear),
                label: const Text('移除遮罩'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: state.isLoading ? null : () => _pickMask(notifier),
                icon: const Icon(Icons.layers),
                label: const Text('选择遮罩'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput(EditState state, EditNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '编辑描述',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptController,
          focusNode: _promptFocusNode,
          maxLines: 5,
          maxLength: ApiConfig.maxEditPromptLength,
          decoration: InputDecoration(
            hintText: '描述你想要的编辑效果...',
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

  Widget _buildBasicParams(EditState state, EditNotifier notifier) {
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
                            onTap: state.isLoading ||
                                    state.n <= ApiConfig.minGenerateCount
                                ? null
                                : () => notifier.updateN(state.n - 1),
                            child: const Icon(Icons.remove, size: 20),
                          ),
                          Text(
                            '${state.n}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          InkWell(
                            onTap: state.isLoading ||
                                    state.n >= ApiConfig.maxGenerateCount
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

  Widget _buildAdvancedParams(EditState state, EditNotifier notifier) {
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
              items: ApiConfig.editModels.map((model) {
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
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: state.background,
                    decoration: const InputDecoration(labelText: '背景透明度'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('默认')),
                      ...ApiConfig.backgroundOptions.map((bg) {
                        return DropdownMenuItem(value: bg, child: Text(bg));
                      }),
                    ],
                    onChanged: state.isLoading
                        ? null
                        : notifier.updateBackground,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String?>(
              value: state.moderation,
              decoration: const InputDecoration(labelText: '内容过滤级别'),
              items: [
                const DropdownMenuItem(value: null, child: Text('默认')),
                ...ApiConfig.moderationOptions.map((mod) {
                  return DropdownMenuItem(value: mod, child: Text(mod));
                }),
              ],
              onChanged: state.isLoading
                  ? null
                  : notifier.updateModeration,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(
    EditState state,
    EditNotifier notifier,
    SettingsState settings,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.isLoading
                ? null
                : (settings.hasApiKey ? () => notifier.edit() : null),
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit),
            label: Text(
              state.isLoading
                  ? 'AI 正在编辑图片，请稍候...'
                  : (settings.hasApiKey ? '编辑图片' : '请先配置 API Key'),
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

  Widget _buildResults(EditState state, EditNotifier notifier) {
    if (state.status == EditStatus.idle && !state.hasImages) {
      return _buildEmptyState();
    }

    if (state.status == EditStatus.error) {
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
                '编辑结果',
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
            Icons.photo_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '选择一张或多张图片，开始 AI 编辑',
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

  Future<void> _pickImage(EditNotifier notifier) async {
    final image = await ImageUtils.pickImageFromGallery();
    if (image != null) {
      notifier.addSourceImage(image);
    }
  }

  Future<void> _pickMask(EditNotifier notifier) async {
    final image = await ImageUtils.pickImageFromGallery();
    if (image != null) {
      notifier.setMaskImage(image);
    }
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
