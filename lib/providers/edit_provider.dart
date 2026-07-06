import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../exceptions/app_exception.dart';
import '../models/edit/edit_request.dart';
import '../models/image_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/image_repository.dart';

class EditState {
  final List<ImageResult> images;
  final bool isLoading;
  final String? error;
  final String? prompt;

  const EditState({
    this.images = const [],
    this.isLoading = false,
    this.error,
    this.prompt,
  });

  EditState copyWith({
    List<ImageResult>? images,
    bool? isLoading,
    String? error,
    String? prompt,
  }) {
    return EditState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      prompt: prompt ?? this.prompt,
    );
  }

  EditState clearError() {
    return EditState(
      images: images,
      isLoading: isLoading,
      prompt: prompt,
    );
  }
}

class EditNotifier extends StateNotifier<EditState> {
  final ImageRepository _imageRepository;
  final Ref _ref;

  EditNotifier(this._imageRepository, this._ref) : super(const EditState());

  Future<void> editImage({
    required String prompt,
    required List<String> imagePaths,
    String? model,
    String? size,
    int? n,
    CancelToken? cancelToken,
  }) async {
    if (prompt.trim().isEmpty) {
      state = state.copyWith(error: '请输入编辑提示词');
      return;
    }

    if (imagePaths.isEmpty) {
      state = state.copyWith(error: '请选择至少一张图片');
      return;
    }

    final settings = _ref.read(settingsProvider);
    final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();
    final selectedModel = model ?? profile.defaultModel;
    final selectedSize = size ?? profile.defaultSize;
    final count = n ?? profile.defaultCount;

    final imageBytesList = <Uint8List>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        imageBytesList.add(bytes);
      }
    }

    if (imageBytesList.isEmpty) {
      state = state.copyWith(error: '无法读取图片文件');
      return;
    }

    state = state.copyWith(
      images: const [],
      isLoading: true,
      error: null,
      prompt: prompt,
    );

    try {
      final request = EditRequest(
        images: imageBytesList,
        prompt: prompt,
        model: selectedModel,
        n: count,
        size: selectedSize,
        quality: 'auto',
      );

      final images = await _imageRepository.editImage(
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

final editProvider = StateNotifierProvider<EditNotifier, EditState>((ref) {
  final imageRepository = ref.watch(imageRepositoryProvider);
  return EditNotifier(imageRepository, ref);
});
