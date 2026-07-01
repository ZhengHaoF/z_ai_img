import 'package:dio/dio.dart';
import '../models/chat/chat_models.dart';
import '../config/api_config.dart';
import '../models/network_log.dart';

/// 网络日志回调
typedef LogCallback = void Function(NetworkLog log);

class ChatService {
  final Dio _dio;
  final String _baseUrl;
  String? _apiKey;
  LogCallback? _onLog;
  final Map<String, DateTime> _requestTimestamps = {};

  ChatService({
    required Dio dio,
    String? baseUrl,
    LogCallback? onLog,
  })  : _dio = dio,
        _baseUrl = baseUrl ?? ApiConfig.chatBaseUrl,
        _onLog = onLog;

  void updateApiKey(String? apiKey) {
    _apiKey = apiKey;
  }

  void setLogCallback(LogCallback? callback) {
    _onLog = callback;
  }

  /// 发送对话请求
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

    // 记录请求日志
    _onLog?.call(
      NetworkLog(
        id: requestId,
        type: NetworkLogType.request,
        timestamp: DateTime.now(),
        method: 'POST',
        url: url,
        headers: {
          'Authorization': 'Bearer ${_apiKey ?? ''}',
          'Content-Type': 'application/json',
        },
        data: request.toJson(),
      ),
    );

    final response = await _dio.post(
      url,
      data: request.toJson(),
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    // 记录响应日志
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
  }
}