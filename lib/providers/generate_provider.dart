import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/generate/generate_request.dart';
import '../../models/image_result.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/image_repository.dart';
import '../../utils/foreground_service.dart';
import '../../utils/native_foreground_service.dart';
import '../../core/state/base_state.dart';
import '../../core/platform/platform_capabilities.dart';

class GenerateState {
  final OperationState<List<ImageResult>> operation;
  final String prompt;
  final String model;
  final String size;
  final String format;
  final String quality;
  final int n;

  const GenerateState({
    this.operation = const OperationState.idle(),
    this.prompt = '',
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.format = 'jpeg',
    this.quality = 'medium',
    this.n = 1,
  });

  GenerateState copyWith({
    OperationState<List<ImageResult>>? operation,
    String? prompt,
    String? model,
    String? size,
    String? format,
    String? quality,
    int? n,
  }) {
    return GenerateState(
      operation: operation ?? this.operation,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      n: n ?? this.n,
    );
  }

  bool get isLoading => operation.isLoading;

  List<ImageResult>? get images => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (data) => data,
    error: (_, __) => null,
  );

  String? get errorMessage => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (_) => null,
    error: (message, _) => message,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerateState &&
          other.operation == operation &&
          other.prompt == prompt &&
          other.model == model &&
          other.size == size &&
          other.format == format &&
          other.quality == quality &&
          other.n == n;

  @override
  int get hashCode => Object.hash(
    operation,
    prompt,
    model,
    size,
    format,
    quality,
    n,
  );
}

class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _repository;
  CancelToken? _cancelToken;

  GenerateNotifier(this._repository, {
    String model = 'gpt-image-2',
    String size = '1024x1024',
    int n = 1,
  }) : super(const GenerateState()) {
    _loadDefaults(model: model, size: size, n: n);
  }

  void _loadDefaults({required String model, required String size, required int n}) {
    state = state.copyWith(
      model: model,
      size: size,
      n: n,
    );
    _loadPresets();
  }

  void _loadPresets() {
    debugPrint('加载默认预设');
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
    if (state.prompt.trim().isEmpty) {
      state = state.copyWith(
        operation: const OperationState.error('请输入提示词'),
      );
      return;
    }

    debugPrint('[GenerateNotifier] generate() 被调用, prompt=${state.prompt.substring(0, state.prompt.length.clamp(0, 20))}...');

    _cancelToken = CancelToken();
    state = state.copyWith(
      operation: const OperationState.loading(progress: 0),
    );
    debugPrint('[GenerateNotifier] state 设置为 loading');

    if (PlatformCapabilities.supportsForegroundService) {
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
        operation: OperationState.success(results),
      );

      if (PlatformCapabilities.supportsForegroundService) {
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
        state = const GenerateState();
      } else {
        state = state.copyWith(
          operation: OperationState.error(e.message ?? '生成失败', error: e),
        );
      }
      if (PlatformCapabilities.supportsForegroundService) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(
        operation: OperationState.error(e.toString(), error: e),
      );
      if (PlatformCapabilities.supportsForegroundService) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
      }
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    if (PlatformCapabilities.supportsForegroundService) {
      NativeForegroundService.stop();
      ForegroundService.cancelGenerating();
    }
  }

  void reset() {
    cancel();
    state = const GenerateState();
  }

  void clearImages() {
    final current = state.images;
    if (current == null || current.isEmpty) return;
    state = state.copyWith(
      operation: const OperationState.idle(),
    );
  }
}

final generateProvider = StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  final repository = ref.watch(imageRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  return GenerateNotifier(
    repository,
    model: settings.defaultModel,
    size: settings.defaultSize,
    n: settings.defaultCount,
  );
});
