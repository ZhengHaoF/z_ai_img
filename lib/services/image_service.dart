import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/generate/generate_request.dart';
import '../models/generate/generate_response.dart';
import '../models/edit/edit_request.dart';
import '../models/edit/edit_response.dart';
import 'api_client.dart';

class ImageService {
  final ApiClient _apiClient;

  ImageService(this._apiClient);

  Future<GenerateResponse> generateImage({
    required GenerateRequest request,
    CancelToken? cancelToken,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConfig.generationsEndpoint,
      data: request.toJson(),
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data == null) {
      return GenerateResponse(data: [], error: 'Empty response');
    }

    // 优先尝试标准 data 数组格式
    if (data['data'] != null) {
      return GenerateResponse.fromJson(data);
    }

    // 兜底尝试 choices 格式
    if (data['choices'] != null) {
      return GenerateResponse.fromChoices(data);
    }

    return GenerateResponse.fromJson(data);
  }

  Future<EditResponse> editImage({
    required EditRequest request,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData();

    // 添加图片文件
    for (int i = 0; i < request.images.length; i++) {
      formData.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(
            request.images[i],
            filename: 'image_$i.png',
          ),
        ),
      );
    }

    // 添加遮罩图片（可选）
    if (request.mask != null) {
      formData.files.add(
        MapEntry(
          'mask',
          MultipartFile.fromBytes(
            request.mask!,
            filename: 'mask.png',
          ),
        ),
      );
    }

    // 添加其他字段
    final fields = request.toFormData();
    for (final entry in fields.entries) {
      if (entry.value != null) {
        formData.fields.add(MapEntry(entry.key, entry.value.toString()));
      }
    }

    final response = await _apiClient.postFormData<Map<String, dynamic>>(
      ApiConfig.editsEndpoint,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );

    final data = response.data;
    if (data == null) {
      return EditResponse(data: [], error: 'Empty response');
    }

    return EditResponse.fromJson(data);
  }
}
