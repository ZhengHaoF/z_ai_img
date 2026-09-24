import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../exceptions/app_exception.dart';
import '../models/generate/generate_request.dart';
import '../models/image_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/image_repository.dart';
import '../utils/native_foreground_service.dart';

class GenerateState {
  final List<ImageResult> images;
  final bool isLoading;
  final String? error;
  final String? prompt;

  const GenerateState({
    this.images = const [],
    this.isLoading = false,
    this.error,
    this.prompt,
  });

  GenerateState copyWith({
    List<ImageResult>? images,
    bool? isLoading,
    String? error,
    String? prompt,
  }) {
    return GenerateState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      prompt: prompt ?? this.prompt,
    );
  }

  GenerateState clearError() {
    return GenerateState(
      images: images,
      isLoading: isLoading,
      prompt: prompt,
    );
  }
}

class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _imageRepository;
  final Ref _ref;

  GenerateNotifier(this._imageRepository, this._ref) : super(const GenerateState());

  Future<void> generateImage({
    required String prompt,
    String? model,
    String? size,
    int? n,
    CancelToken? cancelToken,
  }) async {
    if (prompt.trim().isEmpty) {
      state = state.copyWith(error: '请输入提示词');
      return;
    }

    final settings = _ref.read(settingsProvider);
    final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();
    final selectedModel = model ?? profile.defaultModel;
    final selectedSize = size ?? profile.defaultSize;
    final maxCount = profile.maxCount;
    final rawCount = n ?? profile.defaultCount;
    final count = rawCount.clamp(ApiConfig.minGenerateCount, maxCount);
    final isCompat = profile.usesCompatibleProtocol;

    state = state.copyWith(
      isLoading: true,
      error: null,
      prompt: prompt,
    );

    // 启动 Android 原生前台服务保活，防止切后台被系统杀死
    await NativeForegroundService.start(
      title: '🎨 正在生成图片',
      body: 'AI 正在处理，请稍候...',
    );

    try {
      final request = GenerateRequest(
        model: selectedModel,
        prompt: prompt,
        n: count,
        size: selectedSize,
        // 兼容协议（千问等）不识别 quality/format，不发送以免 400。
        quality: isCompat ? null : 'auto',
        format: isCompat ? null : 'png',
      );

      final images = await _imageRepository.generateImage(
        request: request,
        cancelToken: cancelToken,
      );

      state = state.copyWith(
        images: state.images + images,
        isLoading: false,
      );
    } on AppException catch (e) {
      // 取消（CancelException）不算错误，不弹错误横幅，仅结束 loading。
      if (e is CancelException) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: e.message);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    } finally {
      // 无论成功/失败/取消，都停止前台服务
      await NativeForegroundService.stop();
    }
  }

  void clearError() {
    state = state.clearError();
  }

  void clearResults() {
    state = GenerateState(prompt: state.prompt);
  }
}

final generateProvider = StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  final imageRepository = ref.watch(imageRepositoryProvider);
  return GenerateNotifier(imageRepository, ref);
});
