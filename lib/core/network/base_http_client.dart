import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../exceptions/app_exception.dart';
import '../../models/network_log.dart';

typedef NetworkLogCallback = void Function(NetworkLog log);

class BaseHttpClient {
  late final Dio _dio;
  late final Dio _downloadDio;
  final NetworkLogCallback? onLog;
  final Map<String, DateTime> _requestTimestamps = {};

  BaseHttpClient({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, String>? defaultHeaders,
    String? authToken,
    this.onLog,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
        connectTimeout: connectTimeout ?? ApiConfig.connectTimeout,
        receiveTimeout: receiveTimeout ?? ApiConfig.receiveTimeout,
        persistentConnection: true,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (defaultHeaders != null) ...defaultHeaders,
        },
      ),
    );

    _downloadDio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? ApiConfig.connectTimeout,
        receiveTimeout: receiveTimeout ?? ApiConfig.receiveTimeout,
      ),
    );

    if (authToken != null && authToken.isNotEmpty) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['Authorization'] = 'Bearer $authToken';
            return handler.next(options);
          },
        ),
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final requestId = options.uri.toString();
          _requestTimestamps[requestId] = DateTime.now();
          if (onLog != null) {
            onLog!(
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
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final requestId = response.requestOptions.uri.toString();
          final startTime = _requestTimestamps.remove(requestId);
          final duration = startTime != null ? DateTime.now().difference(startTime) : null;
          if (onLog != null) {
            onLog!(
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
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          final requestId = error.requestOptions.uri.toString();
          final startTime = _requestTimestamps.remove(requestId);
          final duration = startTime != null ? DateTime.now().difference(startTime) : null;
          if (onLog != null) {
            onLog!(
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
          }
          return handler.next(error);
        },
      ),
    );
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

  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void updateHeaders(Map<String, String> headers) {
    _dio.options.headers.addAll(headers);
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
