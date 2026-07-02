import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../models/edit/edit_request.dart';
import '../models/image_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/image_repository.dart';
import '../utils/notification_service.dart' show showNotification;
import '../utils/foreground_service.dart';
import '../utils/background_service_helper.dart';

// Edit state
enum EditStatus { idle, loading, uploading, success, error }

class EditState {
  final EditStatus status;
  final List<ImageResult> images;
  final List<Uint8List> sourceImages;
  final Uint8List? maskImage;
  final String? errorMessage;
  final String prompt;
  final String model;
  final String size;
  final String quality;
  final String? background;
  final String? moderation;
  final int n;
  final double progress;

  const EditState({
    this.status = EditStatus.idle,
    this.images = const [],
    this.sourceImages = const [],
    this.maskImage,
    this.errorMessage,
    this.prompt = '',
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.quality = 'medium',
    this.background,
    this.moderation,
    this.n = 1,
    this.progress = 0,
  });

  EditState copyWith({
    EditStatus? status,
    List<ImageResult>? images,
    List<Uint8List>? sourceImages,
    Uint8List? maskImage,
    String? errorMessage,
    String? prompt,
    String? model,
    String? size,
    String? quality,
    String? background,
    String? moderation,
    int? n,
    double? progress,
    bool clearMask = false,
  }) {
    return EditState(
      status: status ?? this.status,
      images: images ?? this.images,
      sourceImages: sourceImages ?? this.sourceImages,
      maskImage: clearMask ? null : (maskImage ?? this.maskImage),
      errorMessage: errorMessage,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      background: background ?? this.background,
      moderation: moderation ?? this.moderation,
      n: n ?? this.n,
      progress: progress ?? this.progress,
    );
  }

  bool get isLoading => status == EditStatus.loading || status == EditStatus.uploading;
  bool get hasImages => images.isNotEmpty;
  bool get hasSourceImages => sourceImages.isNotEmpty;
}

// Edit notifier
class EditNotifier extends StateNotifier<EditState> {
  final ImageRepository _repository;
  final Ref _ref;
  CancelToken? _cancelToken;

  EditNotifier(this._repository, this._ref) : super(const EditState()) {
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
        status: EditStatus.error,
        errorMessage: '请选择至少一张图片',
      );
      return;
    }

    if (state.prompt.trim().isEmpty) {
      state = state.copyWith(
        status: EditStatus.error,
        errorMessage: '请输入编辑描述',
      );
      return;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      status: EditStatus.uploading,
      errorMessage: null,
      progress: 0,
    );

    // 启动后台服务（仅 Android 端，不显示通知打扰用户）
    if (!kIsWeb) {
      try {
        await BackgroundServiceHelper.startService();
      } catch (e) {
        debugPrint('启动后台服务失败: $e');
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

      state = state.copyWith(status: EditStatus.loading);

      final results = await _repository.editImage(
        request: request,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(progress: sent / total);
          }
        },
      );

      state = state.copyWith(
        status: EditStatus.success,
        images: results,
      );

      // 显示完成通知 + 更新平台状态
      if (kIsWeb) {
        showNotification(
          '🖼️ 图片编辑完成',
          '已生成 ${results.length} 张图片，点击查看',
        );
      } else {
        await ForegroundService.showCompletedNotification(
          title: '🖼️ 图片编辑完成',
          body: '已生成 ${results.length} 张图片，点击查看',
        );
        // 停止后台服务
        if (!kIsWeb) {
          // BackgroundServiceHelper.stopService();
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(
          status: EditStatus.idle,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: EditStatus.error,
          errorMessage: e.message ?? '编辑失败',
        );
      }
      // 取消通知 + 隐藏平台状态
      if (!kIsWeb) {
        ForegroundService.cancelAll();
        // BackgroundServiceHelper.stopService();
      }
    } catch (e) {
      state = state.copyWith(
        status: EditStatus.error,
        errorMessage: e.toString(),
      );
      // 取消通知 + 隐藏平台状态
      if (!kIsWeb) {
        ForegroundService.cancelAll();
        // BackgroundServiceHelper.stopService();
      }
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    // 取消通知
    if (!kIsWeb) {
      ForegroundService.cancelAll();
    }
  }

  void reset() {
    cancel();
    state = const EditState();
    _loadDefaults();
  }

  void clearImages() {
    state = state.copyWith(
      images: [],
      status: EditStatus.idle,
    );
  }
}

// Edit provider
final editProvider = StateNotifierProvider<EditNotifier, EditState>((ref) {
  final repository = ref.watch(imageRepositoryProvider);
  return EditNotifier(repository, ref);
});
