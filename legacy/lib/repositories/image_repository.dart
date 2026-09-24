import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../core/storage/image_storage.dart';
import '../exceptions/app_exception.dart';
import '../models/edit/edit_request.dart';
import '../models/generate/generate_request.dart';
import '../models/image_result.dart';
import '../services/api_client.dart';
import '../services/image_service.dart';

class ImageRepository {
  final ImageService _imageService;
  final ApiClient _apiClient;
  final ImageStorage _imageStorage;
  final Map<String, ImageResult> _cache = {};
  final List<String> _cacheOrder = [];

  ImageRepository(this._imageService, this._apiClient, this._imageStorage);

  Future<List<ImageResult>> generateImage({
    required GenerateRequest request,
    CancelToken? cancelToken,
  }) async {
    final response = await _imageService.generateImage(
      request: request,
      cancelToken: cancelToken,
    );

    if (response.hasError) {
      throw ApiException(response.error ?? '生成图片失败');
    }

    final results = <ImageResult>[];

    for (final imageData in response.data) {
      Uint8List? imageBytes;

      if (imageData.hasB64Json) {
        imageBytes = Uint8List.fromList(base64Decode(imageData.b64Json!));
      } else if (imageData.url != null && imageData.url!.isNotEmpty) {
        imageBytes = await _apiClient.downloadImage(
          imageData.url!,
          cancelToken: cancelToken,
        );
      }

      if (imageBytes != null) {
        final result = ImageResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageData: imageBytes,
          prompt: request.prompt,
        );
        results.add(result);
        _addToCache(result);
      }
    }

    return results;
  }

  Future<List<ImageResult>> editImage({
    required EditRequest request,
    bool useJsonImages = false,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final response = await _imageService.editImage(
      request: request,
      useJsonImages: useJsonImages,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );

    if (response.hasError) {
      throw ApiException(response.error ?? '编辑图片失败');
    }

    final results = <ImageResult>[];

    for (final imageData in response.data) {
      Uint8List? imageBytes;

      if (imageData.hasB64Json) {
        imageBytes = Uint8List.fromList(base64Decode(imageData.b64Json!));
      } else if (imageData.url != null && imageData.url!.isNotEmpty) {
        imageBytes = await _apiClient.downloadImage(
          imageData.url!,
          cancelToken: cancelToken,
        );
      }

      if (imageBytes != null) {
        final result = ImageResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageData: imageBytes,
          prompt: request.prompt,
        );
        results.add(result);
        _addToCache(result);
      }
    }

    return results;
  }

  void _addToCache(ImageResult result) {
    _cache.remove(result.id);
    _cacheOrder.remove(result.id);

    _cache[result.id] = result;
    _cacheOrder.add(result.id);

    while (_cacheOrder.length > ApiConfig.maxImageCacheSize) {
      final oldestId = _cacheOrder.removeAt(0);
      _cache.remove(oldestId);
    }

    // 磁盘写入是异步操作，这里不阻塞返回；但需捕获异常避免 unhandled async error。
    unawaited(
      _imageStorage
          .save(result.id, result.imageData)
          .then<void>((_) {})
          .catchError((Object e) {
        debugPrint('写入图片缓存失败: $e');
      }),
    );
  }

  /// 清空内存缓存与磁盘缓存。
  Future<void> clearCache() async {
    _cache.clear();
    _cacheOrder.clear();
    try {
      await _imageStorage.clear();
    } catch (e) {
      debugPrint('清空磁盘缓存失败: $e');
    }
  }

  int get cacheSize => _cache.length;
}
