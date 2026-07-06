import '../core/network/base_http_client.dart';
import '../config/api_config.dart';

typedef NetworkLogCallback = void Function(dynamic log);

class ApiClient extends BaseHttpClient {
  ApiClient({String? baseUrl, String? apiKey, NetworkLogCallback? onLog})
      : super(
          baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
          authToken: apiKey,
          onLog: onLog,
        );

  void updateConfig({String? baseUrl, String? apiKey}) {
    if (baseUrl != null) {
      updateBaseUrl(baseUrl);
    }
  }
}
