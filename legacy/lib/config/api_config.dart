/// 图生图 / 图编辑请求协议。
///
/// - [openaiImages]：OpenAI 官方 Images 协议。文生图带 `quality`/`format`，
///   图编辑走 multipart `POST /v1/images/edits`（可含 mask）。
/// - [openaiCompatible]：OpenAI 兼容扩展（如千问 `compatible-mode`）。
///   文生图/图编辑共用 `POST /v1/images/generations`，图编辑通过 JSON `image`
///   字段传 URL 或 Base64 data URI；不发送 `quality`/`format`，不支持 mask。
enum ApiProtocol {
  openaiImages,
  openaiCompatible;

  bool get isCompatible => this == ApiProtocol.openaiCompatible;

  static ApiProtocol fromName(String? name) {
    switch (name) {
      case 'openaiCompatible':
      case 'compatible':
      case 'qwen':
        return ApiProtocol.openaiCompatible;
      case 'openaiImages':
      case 'openai':
      default:
        return ApiProtocol.openaiImages;
    }
  }

  String get storageName => name;

  String get label => switch (this) {
        ApiProtocol.openaiImages => 'OpenAI Images（multipart 编辑）',
        ApiProtocol.openaiCompatible => 'OpenAI 兼容扩展（千问等，JSON image）',
      };
}

class ApiProfile {
  final String id;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String defaultModel;
  final String defaultSize;
  final int defaultCount;

  /// 可选模型列表；为空时回退到 [ApiConfig.generateModels] / [ApiConfig.editModels]。
  final List<String> models;

  /// 请求协议，决定图编辑路径与是否附带 quality/format。
  final ApiProtocol apiProtocol;

  const ApiProfile({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.models = const [],
    this.apiProtocol = ApiProtocol.openaiImages,
  });

  bool get usesCompatibleProtocol => apiProtocol.isCompatible;

  /// 当前配置下可用的模型列表（保证包含 defaultModel）。
  List<String> availableModels({required bool forEdit}) {
    final base = models.isNotEmpty
        ? models
        : (forEdit ? ApiConfig.editModels : ApiConfig.generateModels);
    if (defaultModel.isEmpty || base.contains(defaultModel)) {
      return List<String>.unmodifiable(base);
    }
    return List<String>.unmodifiable([defaultModel, ...base]);
  }

  int get maxCount =>
      apiProtocol.isCompatible ? ApiConfig.maxGenerateCountCompat : ApiConfig.maxGenerateCount;

  List<String> get allowedSizes =>
      apiProtocol.isCompatible ? ApiConfig.imageSizesCompat : ApiConfig.imageSizes;

  ApiProfile copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    List<String>? models,
    ApiProtocol? apiProtocol,
  }) {
    return ApiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      models: models ?? this.models,
      apiProtocol: apiProtocol ?? this.apiProtocol,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'defaultModel': defaultModel,
      'defaultSize': defaultSize,
      'defaultCount': defaultCount,
      'models': models,
      'apiProtocol': apiProtocol.storageName,
    };
  }

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    return ApiProfile(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      defaultModel: json['defaultModel'] as String? ?? 'gpt-image-2',
      defaultSize: json['defaultSize'] as String? ?? '1024x1024',
      defaultCount: (json['defaultCount'] as int?) ?? 1,
      models: rawModels is List
          ? rawModels.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
          : const [],
      apiProtocol: ApiProtocol.fromName(json['apiProtocol'] as String?),
    );
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

  // 图片尺寸选项（OpenAI Images / 通用）
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

  // 兼容协议（千问等）推荐尺寸：面积约 ≤2048x2048，宽高比 1:8 ~ 8:1
  static const List<String> imageSizesCompat = [
    '1024x1024',
    '1536x1024',
    '1024x1536',
    '2048x2048',
    '2048x1152',
    '1152x2048',
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
  static const int maxGenerateCountCompat = 6;

  // 提示词最大字符数
  static const int maxPromptLength = 1000;
  static const int maxEditPromptLength = 32000;

  // LRU 缓存上限
  static const int maxImageCacheSize = 20;

  static const String sharedProfilesKey = 'apiProfiles';
  static const String sharedActiveProfileIdKey = 'activeProfileId';

  static ApiProfile defaultProfile() {
    return const ApiProfile(
      id: 'default',
      name: '默认配置',
      apiKey: '',
      baseUrl: 'https://jeniya.cn',
      defaultModel: 'gpt-image-2',
      defaultSize: '1024x1024',
      defaultCount: 1,
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
