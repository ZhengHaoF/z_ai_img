import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../exceptions/app_exception.dart';
import '../models/network_log.dart';

typedef NetworkLogCallback = void Function(NetworkLog log);

class ApiClient {
  late final Dio _dio;
  late final Dio _downloadDio;
  String _baseUrl;
  String? _apiKey;
  final NetworkLogCallback? onLog;
  final Map<String, DateTime> _requestTimestamps = {};

  ApiClient({String? baseUrl, String? apiKey, this.onLog})
      : _baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
        _apiKey = apiKey {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        // 保持长连接，提高后台请求成功率
        persistentConnection: true,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _downloadDio = Dio(
      BaseOptions(
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_apiKey != null && _apiKey!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_apiKey';
          }
          final requestId = options.uri.toString();
          _requestTimestamps[requestId] = DateTime.now();
          if (kDebugMode) {
            debugPrint('=== API Request ===');
            debugPrint('${options.method} ${options.uri}');
            debugPrint('Headers: ${options.headers}');
            if (options.data != null) {
              debugPrint('Data: ${options.data}');
            }
          }
          onLog?.call(
            NetworkLog(
              id: requestId,
              type: NetworkLogType.request,
              timestamp: DateTime.now(),
              method: options.method,
              url: options.uri.toString(),
              headers: Map<String, dynamic>.from(options.headers),
              data: options.data,
            ),
          );
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final requestId = response.requestOptions.uri.toString();
          final startTime = _requestTimestamps.remove(requestId);
          final duration = startTime != null
              ? DateTime.now().difference(startTime)
              : null;
          if (kDebugMode) {
            debugPrint('=== API Response ===');
            debugPrint('Status: ${response.statusCode}');
            debugPrint('Data: ${response.data}');
          }
          onLog?.call(
            NetworkLog(
              id: requestId,
              type: NetworkLogType.response,
              timestamp: DateTime.now(),
              method: response.requestOptions.method,
              url: response.requestOptions.uri.toString(),
              statusCode: response.statusCode,
              data: response.data,
              duration: duration,
            ),
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          final requestId = error.requestOptions.uri.toString();
          final startTime = _requestTimestamps.remove(requestId);
          final duration = startTime != null
              ? DateTime.now().difference(startTime)
              : null;
          if (kDebugMode) {
            debugPrint('=== API Error ===');
            debugPrint('${error.type}: ${error.message}');
          }
          onLog?.call(
            NetworkLog(
              id: requestId,
              type: NetworkLogType.error,
              timestamp: DateTime.now(),
              method: error.requestOptions.method,
              url: error.requestOptions.uri.toString(),
              statusCode: error.response?.statusCode,
              errorMessage: error.message,
              duration: duration,
            ),
          );
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

  Future<Uint8List> downloadImage(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await _downloadDio.get<List<int>>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      if (response.data != null) {
        return Uint8List.fromList(response.data!);
      }
      throw NetworkException('下载图片失败', code: 'EMPTY_RESPONSE');
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
