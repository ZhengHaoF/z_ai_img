import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/edit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/foreground_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/result_grid.dart';
import '../preview/image_preview_page.dart';

class EditPage extends ConsumerStatefulWidget {
  const EditPage({super.key});

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage>
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
    final editState = ref.read(editProvider);

    if (state == AppLifecycleState.paused) {
      if (editState.isLoading) {
        ForegroundService.updateGeneratingNotification(
          title: '⏸️ 图片编辑中',
          body: '编辑仍在继续，切回 App 查看结果',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      final error = editState.error;
      if (error != null && _isBackgroundInterruptedError(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ 由于切后台，编辑任务可能已中断。是否重新尝试？'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                final prompt = _promptController.text.trim();
                final editState = ref.read(editProvider);
                if (prompt.isNotEmpty && editState.selectedImages.isNotEmpty) {
                  _cancelToken = CancelToken();
                  ref.read(editProvider.notifier).editImage(
                    prompt: prompt,
                    imagePaths: editState.selectedImagePaths,
                    images: editState.selectedImages,
                    maskImage: editState.maskImage,
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
    final state = ref.watch(editProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(editProvider.notifier);
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
                    _buildSourceImageSection(state, notifier),
                    const SizedBox(height: 16),
                    _buildMaskImageSection(state, notifier),
                    const SizedBox(height: 16),
                    _buildPromptInput(state, notifier),
                    const SizedBox(height: 16),
                    _buildBasicParams(state, notifier, profile),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      _buildAdvancedParams(state, notifier, profile),
                    ],
                    const SizedBox(height: 16),
                    _buildEditButton(state, notifier, settings),
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

  Widget _buildSourceImageSection(EditState state, EditNotifier notifier) {
    final images = state.selectedImages;
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
            const SizedBox(height: 4),
            Text(
              '选择一张或多张图片进行编辑',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (images.isEmpty)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: state.isLoading ? null : () => notifier.pickSourceImages(),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('添加图片'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('清空'),
                  ),
                ],
              )
            else ...[
              // 图片预览
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < images.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            images[i],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: IconButton(
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            icon: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    final updated = List<Uint8List>.from(images)..removeAt(i);
                                    final updatedPaths = List<String>.from(state.selectedImagePaths);
                                    if (updatedPaths.length > i) updatedPaths.removeAt(i);
                                    notifier.stateUpdated(updated, updatedPaths);
                                  },
                          ),
                        ),
                      ],
                    ),
                  // 添加更多按钮
                  if (!state.isLoading)
                    GestureDetector(
                      onTap: () => notifier.pickSourceImages(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 1.5),
                          color: Colors.grey[50],
                        ),
                        child: Icon(Icons.add, size: 28, color: Colors.grey[400]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: state.isLoading ? null : () => notifier.pickSourceImages(),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('添加图片'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: state.isLoading ? null : () => notifier.clearSourceImages(),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('清空'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaskImageSection(EditState state, EditNotifier notifier) {
    final maskImage = state.maskImage;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '遮罩图片（可选）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '指定编辑区域，仅对第一张图生效',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (maskImage == null)
              OutlinedButton.icon(
                onPressed: state.isLoading || state.selectedImages.isEmpty
                    ? null
                    : () => notifier.pickMaskImage(),
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: const Text('选择遮罩'),
              )
            else
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      maskImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => notifier.clearMaskImage(),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('移除遮罩'),
                  ),
                ],
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

  Widget _buildBasicParams(EditState state, EditNotifier notifier, ApiProfile profile) {
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

  Widget _buildAdvancedParams(EditState state, EditNotifier notifier, ApiProfile profile) {
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
              items: ApiConfig.editModels.map((model) {
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
                : (settings.hasApiKey
                    ? () {
                        final prompt = _promptController.text.trim();
                        if (prompt.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请输入编辑提示词'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _cancelToken = CancelToken();
                        notifier.editImage(
                          prompt: prompt,
                          imagePaths: state.selectedImagePaths,
                          images: state.selectedImages,
                          maskImage: state.maskImage,
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
            onPressed: () {
              _cancelToken?.cancel('用户取消');
            },
            child: const Text('取消'),
          ),
        ],
      ],
    );
  }

  Widget _buildResults(EditState state, EditNotifier notifier) {
    final images = state.images;

    if (images.isEmpty) {
      if (state.isLoading) {
        return const SizedBox.shrink();
      }

      if (state.error != null) {
        return _buildErrorState(state.error);
      }

      return const EmptyState(
        icon: Icons.photo_library_outlined,
        title: '选择一张或多张图片，开始 AI 编辑',
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
            '编辑结果',
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
      content: '确定要清空所有已编辑的图片吗？',
    );

    if (confirmed == true && mounted) {
      ref.read(editProvider.notifier).clearError();
    }
  }
}
