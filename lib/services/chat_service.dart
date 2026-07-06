import 'dart:async';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../models/chat/chat_models.dart';
import '../../models/network_log.dart';
import '../../exceptions/app_exception.dart';

typedef LogCallback = void Function(NetworkLog log);

class ChatService {
  final Dio _dio;
  String _baseUrl;
  LogCallback? _onLog;
  final Map<String, DateTime> _requestTimestamps = {};

  ChatService({
    required Dio dio,
    String? baseUrl,
    String? apiKey,
    LogCallback? onLog,
  })  : _dio = dio,
        _baseUrl = baseUrl ?? ApiConfig.chatBaseUrl,
        _onLog = onLog {
    if (apiKey != null && apiKey.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  void updateApiKey(String? apiKey) {
    if (apiKey != null && apiKey.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
  }

  void setLogCallback(LogCallback? callback) {
    _onLog = callback;
  }

  Future<ChatResponse> sendMessage({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = ApiConfig.defaultTemperature,
    CancelToken? cancelToken,
  }) async {
    final request = ChatRequest(
      model: model,
      messages: messages,
      temperature: temperature,
    );

    final url = '$_baseUrl${ApiConfig.chatCompletionsEndpoint}';
    final requestId = '$url/${DateTime.now().millisecondsSinceEpoch}';
    _requestTimestamps[requestId] = DateTime.now();

    _onLog?.call(
      NetworkLog(
        id: requestId,
        type: NetworkLogType.request,
        timestamp: DateTime.now(),
        method: 'POST',
        url: url,
        headers: Map<String, dynamic>.from(_dio.options.headers),
        data: request.toJson(),
      ),
    );

    try {
      final response = await _dio.post(
        url,
        data: request.toJson(),
        cancelToken: cancelToken,
      );

      final startTime = _requestTimestamps.remove(requestId);
      final duration = startTime != null ? DateTime.now().difference(startTime) : null;
      _onLog?.call(
        NetworkLog(
          id: requestId,
          type: NetworkLogType.response,
          timestamp: DateTime.now(),
          method: 'POST',
          url: url,
          statusCode: response.statusCode,
          data: response.data,
          duration: duration,
        ),
      );

      return ChatResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final startTime = _requestTimestamps.remove(requestId);
      final duration = startTime != null ? DateTime.now().difference(startTime) : null;
      _onLog?.call(
        NetworkLog(
          id: requestId,
          type: NetworkLogType.error,
          timestamp: DateTime.now(),
          method: 'POST',
          url: url,
          statusCode: e.response?.statusCode,
          errorMessage: e.message ?? '网络请求失败',
          duration: duration,
        ),
      );

      if (e.type == DioExceptionType.cancel) {
        throw CancelException();
      }

      throw ApiException(
        e.message ?? '网络请求失败',
        statusCode: e.response?.statusCode,
        code: _errorCode(e.type),
      );
    } catch (e) {
      throw ApiException(
        e.toString(),
        code: 'UNKNOWN',
      );
    }
  }

  String _errorCode(DioExceptionType type) {
    return switch (type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'TIMEOUT',
      DioExceptionType.connectionError => 'CONNECTION_ERROR',
      DioExceptionType.badResponse => 'BAD_RESPONSE',
      DioExceptionType.cancel => 'CANCEL',
      _ => 'UNKNOWN',
    };
  }
}
