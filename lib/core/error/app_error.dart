import 'package:dio/dio.dart';

sealed class AppError implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppError(this.message, {this.code, this.cause});

  bool get isRecoverable => false;
  bool get isAuthError => false;
}

class NetworkException extends AppError {
  const NetworkException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);

  @override
  bool get isRecoverable => true;
}

class ApiException extends AppError {
  final int? statusCode;

  const ApiException(
    String message, {
    this.statusCode,
    String? code,
    Object? cause,
  }) : super(message, code: code, cause: cause);

  @override
  bool get isAuthError => statusCode == 401 || statusCode == 403;
}

class ValidationException extends AppError {
  const ValidationException(String message) : super(message);
}

class CacheException extends AppError {
  const CacheException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

AppError toAppError(Object error) {
  if (error is AppError) return error;
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NetworkException('连接超时，请检查网络后重试', code: 'TIMEOUT', cause: error),
      DioExceptionType.connectionError =>
        NetworkException('网络连接失败，请检查网络后重试', code: 'CONNECTION_ERROR', cause: error),
      DioExceptionType.cancel => const CacheException('请求已取消', code: 'CANCEL'),
      DioExceptionType.badResponse => ApiException(
          '服务器错误',
          statusCode: error.response?.statusCode,
          code: 'BAD_RESPONSE',
          cause: error,
        ),
      _ => NetworkException(error.message ?? '未知错误', code: 'UNKNOWN', cause: error),
    };
  }
  return ApiException(error.toString(), code: 'UNKNOWN', cause: error);
}
