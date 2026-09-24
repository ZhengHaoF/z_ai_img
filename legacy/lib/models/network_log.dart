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

const int _maxLogDataChars = 2048;

/// 对网络日志中的请求头做脱敏处理，避免 API Key 等敏感信息出现在日志 UI 中。
Map<String, dynamic> sanitizeHeaders(Map<String, dynamic>? headers) {
  if (headers == null) return const {};
  final result = Map<String, dynamic>.from(headers);
  result.forEach((key, value) {
    if (key.toLowerCase() == 'authorization') {
      final str = value?.toString() ?? '';
      result[key] = str.startsWith('Bearer ') ? 'Bearer ***' : '***';
    }
  });
  return result;
}

/// 截断过大的请求/响应体，防止日志 UI 因渲染超大字符串而 OOM，并避免大体积数据外泄。
dynamic truncateLogData(dynamic data) {
  if (data == null) return null;
  final str = data.toString();
  if (str.length <= _maxLogDataChars) return data;
  return '${str.substring(0, _maxLogDataChars)}\n…(已截断，原长度 ${str.length} 字符)';
}
