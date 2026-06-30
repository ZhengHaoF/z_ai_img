class ApiConfig {
  ApiConfig._();

  // 默认 API 地址
  static const String defaultBaseUrl = 'https://jeniya.cn';

  // API 端点
  static const String generationsEndpoint = '/v1/images/generations';
  static const String editsEndpoint = '/v1/images/edits';

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);

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
  static const List<String> generateModels = ['gpt-image-2'];

  // 模型选项 - 图编辑
  static const List<String> editModels = [
    'gpt-image-2',
    'gpt-image-2-all',
    'gpt-image-1',
    'flux-kontext-pro',
    'flux-kontext-max',
  ];

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

  // LRU 缓存上限
  static const int maxImageCacheSize = 20;
}
