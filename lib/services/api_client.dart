import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../exceptions/app_exception.dart';

class ApiClient {
  late final Dio _dio;
  String _baseUrl;
  String? _apiKey;

  ApiClient({String? baseUrl, String? apiKey})
      : _baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
        _apiKey = apiKey {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_apiKey != null && _apiKey!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_apiKey';
          }
          if (kDebugMode) {
            debugPrint('=== API Request ===');
            debugPrint('${options.method} ${options.uri}');
            debugPrint('Headers: ${options.headers}');
            if (options.data != null) {
              debugPrint('Data: ${options.data}');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('=== API Response ===');
            debugPrint('Status: ${response.statusCode}');
            debugPrint('Data: ${response.data}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint('=== API Error ===');
            debugPrint('${error.type}: ${error.message}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  void updateConfig({String? baseUrl, String? apiKey}) {
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      _dio.options.baseUrl = baseUrl;
    }
    if (apiKey != null) {
      _apiKey = apiKey;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> postFormData<T>(
    String path, {
    required FormData data,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          '连接超时，请检查网络后重试',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          '网络连接失败，请检查网络后重试',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.cancel:
        return CancelException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message = '服务器错误';

        if (data is Map<String, dynamic>) {
          message = data['error']?['message'] as String? ??
              data['message'] as String? ??
              data['error'] as String? ??
              message;
        }

        return ApiException(
          message,
          statusCode: statusCode,
          code: 'BAD_RESPONSE',
        );
      default:
        return NetworkException(
          error.message ?? '未知错误',
          code: 'UNKNOWN',
        );
    }
  }
}
