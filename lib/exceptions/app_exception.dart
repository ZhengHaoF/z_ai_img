abstract class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code});
}

class ApiException extends AppException {
  final int? statusCode;

  ApiException(super.message, {super.code, this.statusCode});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code});
}

class CancelException extends AppException {
  CancelException([String message = '请求已取消']) : super(message);
}

class CacheException extends AppException {
  CacheException(super.message, {super.code});
}
