import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
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
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final response = await _imageService.editImage(
      request: request,
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

    _imageStorage.save(result.id, result.imageData);
  }

  Future<ImageResult?> getFromCache(String id) async {
    if (_cache.containsKey(id)) {
      _cacheOrder.remove(id);
      _cacheOrder.add(id);
      return _cache[id];
    }

    final bytes = await _imageStorage.load(id);
    if (bytes != null) {
      final result = ImageResult(id: id, imageData: bytes, prompt: '');
      _cache[id] = result;
      _cacheOrder.add(id);
      return result;
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
    _cacheOrder.clear();
  }

  int get cacheSize => _cache.length;
}
