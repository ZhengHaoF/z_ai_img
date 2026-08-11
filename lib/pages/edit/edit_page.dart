import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/edit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/background_error.dart';
import '../../utils/foreground_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/feedback.dart';
import '../../widgets/params/model_selector.dart';
import '../../widgets/params/prompt_field.dart';
import '../../widgets/params/result_section.dart';
import '../../widgets/params/size_count_selector.dart';
import '../../widgets/params/submit_button.dart';
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
      if (error != null && isBackgroundInterruptedError(error)) {
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
              const LinearProgressIndicator(backgroundColor: Colors.transparent),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSourceImageSection(state: state, notifier: notifier),
                    const SizedBox(height: 16),
                    _buildMaskImageSection(state: state, notifier: notifier),
                    const SizedBox(height: 16),
                    PromptField(
                      controller: _promptController,
                      focusNode: _promptFocusNode,
                      enabled: !state.isLoading,
                      title: '编辑描述',
                      hintText: '描述你想要的编辑效果...',
                      maxLength: ApiConfig.maxEditPromptLength,
                    ),
                    const SizedBox(height: 16),
                    SizeAndCountSelector(
                      profile: profile,
                      isLoading: state.isLoading,
                      showAdvanced: _showAdvanced,
                      onToggleAdvanced: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                    ),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      ModelSelector(
                        profile: profile,
                        isLoading: state.isLoading,
                        models: ApiConfig.editModels,
                        label: '模型',
                      ),
                    ],
                    const SizedBox(height: 16),
                    SubmitButton(
                      isLoading: state.isLoading,
                      hasApiKey: settings.hasApiKey,
                      idleLabel: '编辑图片',
                      loadingLabel: 'AI 正在编辑图片，请稍候...',
                      noApiKeyLabel: '请先配置 API Key',
                      icon: Icons.edit,
                      onPressed: () {
                        final prompt = _promptController.text.trim();
                        if (prompt.isEmpty) {
                          showAppSnackBar(context, '请输入编辑提示词');
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
                      },
                      onCancel: () => _cancelToken?.cancel('用户取消'),
                    ),
                    const SizedBox(height: 16),
                    ResultSection(
                      images: state.images,
                      title: '编辑结果',
                      error: state.error,
                      isLoading: state.isLoading,
                      emptyIcon: Icons.photo_library_outlined,
                      emptyTitle: '选择一张或多张图片，开始 AI 编辑',
                      onItemTap: (index) => _openPreview(index, state.images),
                      onItemSave: (index) => saveImageWithFeedback(
                        context,
                        state.images[index].imageData,
                      ),
                      onClear: _onClearPressed,
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

  Widget _buildSourceImageSection({
    required EditState state,
    required EditNotifier notifier,
  }) {
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
                            cacheWidth: 160,
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
                                    final updatedPaths =
                                        List<String>.from(state.selectedImagePaths);
                                    if (updatedPaths.length > i) updatedPaths.removeAt(i);
                                    notifier.stateUpdated(updated, updatedPaths);
                                  },
                          ),
                        ),
                      ],
                    ),
                  if (!state.isLoading)
                    GestureDetector(
                      onTap: () => notifier.pickSourceImages(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
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

  Widget _buildMaskImageSection({
    required EditState state,
    required EditNotifier notifier,
  }) {
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
                      cacheWidth: 120,
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
      ref.read(editProvider.notifier).clearResults();
    }
  }
}
