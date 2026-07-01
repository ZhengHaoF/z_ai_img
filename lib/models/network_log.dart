enum NetworkLogType { request, response, error }

class NetworkLog {
  final String id;
  final NetworkLogType type;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, dynamic>? headers;
  final dynamic data;
  final int? statusCode;
  final String? errorMessage;
  final Duration? duration;

  NetworkLog({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.method,
    required this.url,
    this.headers,
    this.data,
    this.statusCode,
    this.errorMessage,
    this.duration,
  });

  String get typeLabel {
    switch (type) {
      case NetworkLogType.request:
        return 'REQUEST';
      case NetworkLogType.response:
        return 'RESPONSE';
      case NetworkLogType.error:
        return 'ERROR';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
