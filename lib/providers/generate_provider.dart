import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../models/generate/generate_request.dart';
import '../models/image_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/image_repository.dart';
import '../utils/foreground_service.dart';
import '../utils/native_foreground_service.dart';

// Generate state
enum GenerateStatus { idle, loading, success, error, partial }

class GenerateState {
  final GenerateStatus status;
  final List<ImageResult> images;
  final String? errorMessage;
  final String prompt;
  final String model;
  final String size;
  final String format;
  final String quality;
  final int n;
  final double progress;

  const GenerateState({
    this.status = GenerateStatus.idle,
    this.images = const [],
    this.errorMessage,
    this.prompt = '',
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.format = 'jpeg',
    this.quality = 'medium',
    this.n = 1,
    this.progress = 0,
  });

  GenerateState copyWith({
    GenerateStatus? status,
    List<ImageResult>? images,
    String? errorMessage,
    String? prompt,
    String? model,
    String? size,
    String? format,
    String? quality,
    int? n,
    double? progress,
  }) {
    return GenerateState(
      status: status ?? this.status,
      images: images ?? this.images,
      errorMessage: errorMessage,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      n: n ?? this.n,
      progress: progress ?? this.progress,
    );
  }

  bool get isLoading => status == GenerateStatus.loading;
  bool get hasImages => images.isNotEmpty;
}

// Generate notifier
class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _repository;
  final Ref _ref;
  CancelToken? _cancelToken;

  GenerateNotifier(this._repository, this._ref) : super(const GenerateState()) {
    _loadDefaults();
  }

  void _loadDefaults() {
    final settings = _ref.read(settingsProvider);
    state = state.copyWith(
      model: settings.defaultModel,
      size: settings.defaultSize,
      n: settings.defaultCount,
    );
  }

  void updatePrompt(String value) {
    state = state.copyWith(prompt: value);
  }

  void updateModel(String value) {
    state = state.copyWith(model: value);
  }

  void updateSize(String value) {
    state = state.copyWith(size: value);
  }

  void updateFormat(String value) {
    state = state.copyWith(format: value);
  }

  void updateQuality(String value) {
    state = state.copyWith(quality: value);
  }

  void updateN(int value) {
    state = state.copyWith(n: value);
  }

  Future<void> generate() async {
    debugPrint('[GenerateNotifier] generate() 被调用, prompt=${state.prompt.substring(0, state.prompt.length.clamp(0, 20))}...');
    if (state.prompt.trim().isEmpty) {
      debugPrint('[GenerateNotifier] prompt 为空，设置 error 状态');
      state = state.copyWith(
        status: GenerateStatus.error,
        errorMessage: '请输入提示词',
      );
      return;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      status: GenerateStatus.loading,
      errorMessage: null,
      progress: 0,
    );
    debugPrint('[GenerateNotifier] state 设置为 loading');

    // 启动原生前台保活服务 + 进度通知
    if (!kIsWeb) {
      try {
        await NativeForegroundService.start(
          title: '🎨 图片生成中',
          body: state.prompt.length > 30
              ? '${state.prompt.substring(0, 30)}...'
              : state.prompt,
        );
      } catch (e) {
        debugPrint('启动前台保活失败: $e');
      }
      try {
        await ForegroundService.showGeneratingNotification();
      } catch (e) {
        debugPrint('显示生成通知失败: $e');
      }
    }

    try {
      final request = GenerateRequest(
        model: state.model,
        prompt: state.prompt,
        n: state.n,
        size: state.size,
        quality: state.quality,
        format: state.format,
      );

      final results = await _repository.generateImage(
        request: request,
        cancelToken: _cancelToken,
      );

      state = state.copyWith(
        status: GenerateStatus.success,
        images: [...state.images, ...results],
      );

      // 停止保活，显示完成通知
      if (!kIsWeb) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
        try {
          await ForegroundService.showCompletedNotification(
            title: '🎨 图片生成完成',
            body: '已生成 ${results.length} 张图片，点击查看',
          );
        } catch (_) {}
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(
          status: GenerateStatus.idle,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: GenerateStatus.error,
          errorMessage: e.message ?? '生成失败',
        );
      }
      if (!kIsWeb) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(
        status: GenerateStatus.error,
        errorMessage: e.toString(),
      );
      if (!kIsWeb) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
      }
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    // 取消时也停止保活
    if (!kIsWeb) {
      NativeForegroundService.stop();
      ForegroundService.cancelGenerating();
    }
  }

  void reset() {
    cancel();
    state = const GenerateState();
    _loadDefaults();
  }

  void clearImages() {
    state = state.copyWith(
      images: [],
      status: GenerateStatus.idle,
    );
  }
}

// Generate provider
final generateProvider = StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  final repository = ref.watch(imageRepositoryProvider);
  return GenerateNotifier(repository, ref);
});
