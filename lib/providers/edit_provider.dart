import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/edit/edit_request.dart';
import '../models/image_result.dart';
import 'settings_provider.dart';
import '../repositories/image_repository.dart';
import '../utils/foreground_service.dart';
import '../utils/native_foreground_service.dart';
import '../core/state/base_state.dart';
import '../core/platform/platform_capabilities.dart';

class EditState {
  final OperationState<List<ImageResult>> operation;
  final List<Uint8List> sourceImages;
  final Uint8List? maskImage;
  final String prompt;
  final String model;
  final String size;
  final String quality;
  final String? background;
  final String? moderation;
  final int n;

  const EditState({
    this.operation = const OperationState.idle(),
    this.sourceImages = const [],
    this.maskImage,
    this.prompt = '',
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.quality = 'medium',
    this.background,
    this.moderation,
    this.n = 1,
  });

  EditState copyWith({
    OperationState<List<ImageResult>>? operation,
    List<Uint8List>? sourceImages,
    Uint8List? maskImage,
    bool clearMask = false,
    String? prompt,
    String? model,
    String? size,
    String? quality,
    String? background,
    String? moderation,
    int? n,
  }) {
    return EditState(
      operation: operation ?? this.operation,
      sourceImages: sourceImages ?? this.sourceImages,
      maskImage: clearMask ? null : (maskImage ?? this.maskImage),
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      background: background ?? this.background,
      moderation: moderation ?? this.moderation,
      n: n ?? this.n,
    );
  }

  bool get isLoading => operation.isLoading;
  bool get hasImages => _successImages.isNotEmpty;
  bool get hasSourceImages => sourceImages.isNotEmpty;

  List<ImageResult>? get images => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (data) => data,
    error: (_, __) => null,
  );

  List<ImageResult> get _successImages {
    return operation.when(
      idle: () => <ImageResult>[],
      loading: (_) => <ImageResult>[],
      success: (data) => data,
      error: (_, __) => <ImageResult>[],
    );
  }

  String? get errorMessage => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (_) => null,
    error: (message, _) => message,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditState &&
          other.operation == operation &&
          other.sourceImages.length == sourceImages.length &&
          other.maskImage == maskImage &&
          other.prompt == prompt &&
          other.model == model &&
          other.size == size &&
          other.quality == quality &&
          other.background == background &&
          other.moderation == moderation &&
          other.n == n;

  @override
  int get hashCode => Object.hash(
    operation,
    sourceImages.length,
    maskImage,
    prompt,
    model,
    size,
    quality,
    background,
    moderation,
    n,
  );
}

class EditNotifier extends StateNotifier<EditState> {
  final ImageRepository _repository;
  CancelToken? _cancelToken;

  EditNotifier(this._repository, {
    String model = 'gpt-image-2',
    String size = '1024x1024',
    int n = 1,
  }) : super(const EditState()) {
    _loadDefaults(model: model, size: size, n: n);
  }

  void _loadDefaults({required String model, required String size, required int n}) {
    state = state.copyWith(
      model: model,
      size: size,
      n: n,
    );
  }

  void addSourceImage(Uint8List image) {
    state = state.copyWith(
      sourceImages: [...state.sourceImages, image],
    );
  }

  void removeSourceImage(int index) {
    final images = List<Uint8List>.from(state.sourceImages);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      state = state.copyWith(sourceImages: images);
    }
  }

  void clearSourceImages() {
    state = state.copyWith(sourceImages: []);
  }

  void setMaskImage(Uint8List? image) {
    state = state.copyWith(maskImage: image, clearMask: image == null);
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

  void updateQuality(String value) {
    state = state.copyWith(quality: value);
  }

  void updateBackground(String? value) {
    state = state.copyWith(background: value);
  }

  void updateModeration(String? value) {
    state = state.copyWith(moderation: value);
  }

  void updateN(int value) {
    state = state.copyWith(n: value);
  }

  Future<void> edit() async {
    if (!state.hasSourceImages) {
      state = state.copyWith(
        operation: const OperationState.error('请选择至少一张图片'),
      );
      return;
    }

    if (state.prompt.trim().isEmpty) {
      state = state.copyWith(
        operation: const OperationState.error('请输入编辑描述'),
      );
      return;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      operation: const OperationState.loading(progress: 0),
    );

    if (PlatformCapabilities.supportsForegroundService) {
      try {
        await NativeForegroundService.start(
          title: '🖼️ 图片编辑中',
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
      final request = EditRequest(
        images: state.sourceImages,
        prompt: state.prompt,
        mask: state.maskImage,
        model: state.model,
        n: state.n,
        size: state.size,
        quality: state.quality,
        background: state.background,
        moderation: state.moderation,
      );

      final results = await _repository.editImage(
        request: request,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(
              operation: OperationState.loading(progress: sent / total),
            );
          }
        },
      );

      state = state.copyWith(
        operation: OperationState.success(results),
      );

      if (PlatformCapabilities.supportsForegroundService) {
        try { await NativeForegroundService.stop(); } catch (_) {}
        try { await ForegroundService.cancelGenerating(); } catch (_) {}
        try {
          await ForegroundService.showCompletedNotification(
            title: '🖼️ 图片编辑完成',
            body: '已生成 ${results.length} 张图片，点击查看',
          );
        } catch (_) {}
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = const EditState();
      } else {
        state = state.copyWith(
          operation: OperationState.error(e.message ?? '编辑失败', error: e),
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
    state = const EditState();
  }

  void clearImages() {
    final current = state.images;
    if (current == null || current.isEmpty) return;
    state = state.copyWith(
      operation: const OperationState.idle(),
    );
  }
}

final editProvider = StateNotifierProvider<EditNotifier, EditState>((ref) {
  final repository = ref.watch(imageRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  return EditNotifier(
    repository,
    model: settings.defaultModel,
    size: settings.defaultSize,
    n: settings.defaultCount,
  );
});
