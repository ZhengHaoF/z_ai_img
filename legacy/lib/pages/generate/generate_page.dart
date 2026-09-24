import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../models/image_result.dart';
import '../../providers/generate_provider.dart';
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
      if (error != null && isBackgroundInterruptedError(error)) {
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
              const LinearProgressIndicator(backgroundColor: Colors.transparent),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PromptField(
                      controller: _promptController,
                      focusNode: _promptFocusNode,
                      enabled: !state.isLoading,
                      title: '提示词',
                      hintText: '输入描述，开始生成你的 AI 图片',
                      maxLength: ApiConfig.maxPromptLength,
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
                        models: profile.availableModels(forEdit: false),
                        label: '模型',
                      ),
                    ],
                    const SizedBox(height: 16),
                    SubmitButton(
                      isLoading: state.isLoading,
                      hasApiKey: settings.hasApiKey,
                      idleLabel: '生成图片',
                      loadingLabel: 'AI 正在生成中，请稍候...',
                      noApiKeyLabel: '请先配置 API Key',
                      icon: Icons.auto_awesome,
                      onPressed: () {
                        final prompt = _promptController.text.trim();
                        if (prompt.isEmpty) {
                          showAppSnackBar(context, '请输入提示词');
                          return;
                        }
                        _cancelToken = CancelToken();
                        notifier.generateImage(
                          prompt: prompt,
                          cancelToken: _cancelToken,
                        );
                      },
                      onCancel: () => _cancelToken?.cancel('用户取消'),
                    ),
                    const SizedBox(height: 16),
                    ResultSection(
                      images: state.images,
                      title: '生成结果',
                      error: state.error,
                      isLoading: state.isLoading,
                      emptyIcon: Icons.image_outlined,
                      emptyTitle: '输入描述，开始生成你的 AI 图片',
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
      ref.read(generateProvider.notifier).clearResults();
    }
  }
}
