import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../exceptions/app_exception.dart';
import '../models/generate/generate_request.dart';
import '../models/image_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/image_repository.dart';

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
    final count = n ?? profile.defaultCount;

    state = state.copyWith(
      images: const [],
      isLoading: true,
      error: null,
      prompt: prompt,
    );

    try {
      final request = GenerateRequest(
        model: selectedModel,
        prompt: prompt,
        n: count,
        size: selectedSize,
        quality: 'auto',
        format: 'png',
      );

      final images = await _imageRepository.generateImage(
        request: request,
        cancelToken: cancelToken,
      );

      state = state.copyWith(
        images: images,
        isLoading: false,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.clearError();
  }
}

final generateProvider = StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  final imageRepository = ref.watch(imageRepositoryProvider);
  return GenerateNotifier(imageRepository, ref);
});
