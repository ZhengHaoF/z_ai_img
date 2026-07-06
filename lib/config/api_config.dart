class ApiProfile {
  final String id;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String? chatBaseUrl;

  const ApiProfile({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.chatBaseUrl,
  });

  ApiProfile copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? chatBaseUrl,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      chatBaseUrl: chatBaseUrl ?? this.chatBaseUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      if (chatBaseUrl != null) 'chatBaseUrl': chatBaseUrl,
    };
  }

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    return ApiProfile(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      chatBaseUrl: json['chatBaseUrl'] as String?,
    );
  }

  String resolveChatBaseUrl() {
    final trimmed = chatBaseUrl?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    final normalized = baseUrl.trim();
    if (normalized.isEmpty) return ApiConfig.chatBaseUrl;

    if (normalized.contains('/v1/chat')) {
      return normalized;
    }

    if (normalized.endsWith('/v1/images')) {
      return '${normalized.replaceAll('/v1/images', '')}/v1/chat';
    }

    if (normalized.endsWith('/v1/images/')) {
      return '${normalized.replaceAll('/v1/images/', '')}/v1/chat';
    }

    return normalized;
  }
}

class ApiConfig {
  ApiConfig._();

  // 默认 API 地址
  static const String defaultBaseUrl = 'https://jeniya.cn';

  // API 端点
  static const String generationsEndpoint = '/v1/images/generations';
  static const String editsEndpoint = '/v1/images/edits';

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(minutes: 10);

  // 图片尺寸选项
  static const List<String> imageSizes = [
    '1024x1024',   // 方
    '1536x1024',   // 横
    '1024x1536',   // 竖
    '2048x2048',   // 2K方
    '2048x1152',   // 2K横
    '3840x2160',   // 4K横
    '2160x3840',   // 4K竖
    'auto',
  ];

  // 图片格式选项
  static const List<String> imageFormats = ['png', 'jpeg', 'webp'];

  // 画质选项
  static const List<String> qualityOptions = ['low', 'medium', 'high', 'auto'];

  // 模型选项 - 文生图
  static const List<String> generateModels = ['gpt-image-2', 'z-image-turbo'];

  // 模型选项 - 图编辑
  static const List<String> editModels = ['gpt-image-2'];

  // 背景透明度选项
  static const List<String> backgroundOptions = ['transparent', 'opaque', 'auto'];

  // 内容过滤级别
  static const List<String> moderationOptions = ['low', 'auto'];

  // 生成数量范围
  static const int minGenerateCount = 1;
  static const int maxGenerateCount = 10;

  // 提示词最大字符数
  static const int maxPromptLength = 1000;
  static const int maxEditPromptLength = 32000;

  // 对话 API 地址
  static const String chatBaseUrl = 'https://jeniya.top';

  // 对话 API 端点
  static const String chatCompletionsEndpoint = '/v1/chat/completions';

  static String resolveChatBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) return chatBaseUrl;

    if (normalized.contains('/v1/chat')) {
      return normalized;
    }

    if (normalized.endsWith('/v1/images')) {
      return '${normalized.replaceAll('/v1/images', '')}/v1/chat';
    }

    if (normalized.endsWith('/v1/images/')) {
      return '${normalized.replaceAll('/v1/images/', '')}/v1/chat';
    }

    return normalized;
  }

  // 对话模型选项
  static const List<String> chatModels = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'];

  // 默认对话模型
  static const String defaultChatModel = 'gpt-4o';

  // 默认温度
  static const double defaultTemperature = 0.7;

  // LRU 缓存上限
  static const int maxImageCacheSize = 20;

  static const String sharedProfilesKey = 'apiProfiles';
  static const String sharedActiveProfileIdKey = 'activeProfileId';

  static ApiProfile defaultProfile() {
    return ApiProfile(
      id: 'default',
      name: '默认配置',
      apiKey: '',
      baseUrl: defaultBaseUrl,
    );
  }

  static List<ApiProfile> legacyProfile(String baseUrl, String apiKey) {
    return [
      ApiProfile(
        id: 'default',
        name: '默认配置',
        apiKey: apiKey,
        baseUrl: baseUrl,
      ),
    ];
  }
}
