import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/image_utils.dart';
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
  final List<String> selectedImagePaths;
  final String? maskImagePath;
  final List<Uint8List> selectedImages;
  final Uint8List? maskImage;

  const EditState({
    this.images = const [],
    this.isLoading = false,
    this.error,
    this.prompt,
    this.selectedImagePaths = const [],
    this.maskImagePath,
    this.selectedImages = const [],
    this.maskImage,
  });

  EditState copyWith({
    List<ImageResult>? images,
    bool? isLoading,
    String? error,
    String? prompt,
    List<String>? selectedImagePaths,
    String? maskImagePath,
    List<Uint8List>? selectedImages,
    Uint8List? maskImage,
  }) {
    return EditState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      prompt: prompt ?? this.prompt,
      selectedImagePaths: selectedImagePaths ?? this.selectedImagePaths,
      maskImagePath: maskImagePath ?? this.maskImagePath,
      selectedImages: selectedImages ?? this.selectedImages,
      maskImage: maskImage ?? this.maskImage,
    );
  }

  EditState clearError() {
    return EditState(
      images: images,
      isLoading: isLoading,
      prompt: prompt,
      selectedImagePaths: selectedImagePaths,
      maskImagePath: maskImagePath,
      selectedImages: selectedImages,
      maskImage: maskImage,
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
    List<Uint8List>? images,
    Uint8List? maskImage,
    String? model,
    String? size,
    int? n,
    CancelToken? cancelToken,
  }) async {
    if (prompt.trim().isEmpty) {
      state = state.copyWith(error: '请输入编辑提示词');
      return;
    }

    // 优先使用传入的图片字节，否则从路径读取
    final imageBytesList = <Uint8List>[];
    if (images != null && images.isNotEmpty) {
      imageBytesList.addAll(images);
    } else {
      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          imageBytesList.add(bytes);
        }
      }
    }

    if (imageBytesList.isEmpty) {
      state = state.copyWith(error: '请选择至少一张图片');
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
      final request = EditRequest(
        images: imageBytesList,
        prompt: prompt,
        mask: maskImage,
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

  /// 选择源图片（支持多选）
  Future<void> pickSourceImages() async {
    try {
      final images = await ImageUtils.pickMultipleImages();
      if (images.isEmpty) return;

      // 追加到已有选择
      final updated = List<Uint8List>.from(state.selectedImages)..addAll(images);
      // 同时追加路径（非 web 端有路径）
      final updatedPaths = List<String>.from(state.selectedImagePaths);
      if (!kIsWeb) {
        for (int i = 0; i < images.length; i++) {
          updatedPaths.add('source_${state.selectedImagePaths.length + i}');
        }
      }

      state = state.copyWith(
        selectedImages: updated,
        selectedImagePaths: updatedPaths,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: '选择图片失败: $e');
    }
  }

  /// 清空已选源图片
  void clearSourceImages() {
    state = state.copyWith(
      selectedImages: [],
      selectedImagePaths: [],
    );
  }

  /// 选择遮罩图片
  Future<void> pickMaskImage() async {
    try {
      final image = await ImageUtils.pickImageFromGallery();
      if (image == null) return;

      state = state.copyWith(
        maskImage: image,
        maskImagePath: kIsWeb ? 'mask_web' : 'mask_local',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: '选择遮罩失败: $e');
    }
  }

  /// 移除遮罩图片
  void clearMaskImage() {
    state = state.copyWith(
      maskImage: null,
      maskImagePath: null,
    );
  }

  /// 外部更新选中图片（用于单张删除）
  void stateUpdated(List<Uint8List> images, List<String> paths) {
    state = state.copyWith(
      selectedImages: images,
      selectedImagePaths: paths,
    );
  }
}

final editProvider = StateNotifierProvider<EditNotifier, EditState>((ref) {
  final imageRepository = ref.watch(imageRepositoryProvider);
  return EditNotifier(imageRepository, ref);
});
