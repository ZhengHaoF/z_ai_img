# Z Ai 项目 Rework 报告

> **项目名称**：Z Ai - AI 图像生成与编辑应用  
> **技术栈**：Flutter + Dart SDK 3.12+ / Riverpod 2.6+ / Dio 5.8+ / SharedPreferences  
> **目标平台**：Android / iOS / Windows / macOS / Linux / Web  
> **报告日期**：2026-07-05  
> **当前版本**：1.0.0+1  

---

## 目录

1. [项目总览](#一项目总览)
2. [现状诊断 —— 架构与代码级问题清单](#二现状诊断--架构与代码级问题清单)
3. [Rework 目标与范围](#三rework-目标与范围)
4. [分阶段改造计划 —— 详细代码级方案](#四分阶段改造计划--详细代码级方案)
5. [影响文件清单](#五影响文件清单)
6. [回归测试 Checklist](#六回归测试-checklist)
7. [依赖升级计划](#七依赖升级计划)
8. [回滚策略](#八回滚策略)
9. [执行建议](#九执行建议)

---

## 一、项目总览

### 1.1 核心文件结构

```
z_ai_img/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── api_config.dart
│   │   └── themes.dart
│   ├── exceptions/
│   │   └── app_exception.dart
│   ├── models/
│   │   ├── chat/chat_models.dart
│   │   ├── edit/edit_request.dart
│   │   ├── edit/edit_response.dart
│   │   ├── generate/generate_request.dart
│   │   ├── generate/generate_response.dart
│   │   ├── image_result.dart
│   │   └── network_log.dart
│   ├── pages/
│   │   ├── chat/chat_page.dart
│   │   ├── edit/edit_page.dart
│   │   ├── generate/generate_page.dart
│   │   ├── preview/image_preview_page.dart
│   │   ├── settings/settings_page.dart
│   │   └── home_page.dart
│   ├── providers/
│   │   ├── chat_provider.dart
│   │   ├── edit_provider.dart
│   │   ├── generate_provider.dart
│   │   ├── network_log_provider.dart
│   │   └── settings_provider.dart
│   ├── repositories/
│   │   └── image_repository.dart
│   ├── services/
│   │   ├── api_client.dart
│   │   ├── chat_service.dart
│   │   └── image_service.dart
│   ├── utils/
│   │   ├── foreground_service.dart
│   │   ├── image_utils.dart
│   │   ├── image_utils_nonweb.dart
│   │   ├── image_utils_web.dart
│   │   ├── native_foreground_service.dart
│   │   ├── notification_service.dart
│   │   ├── notification_service_nonweb.dart
│   │   ├── notification_service_web.dart
│   │   ├── system_tray.dart
│   │   └── validators.dart
│   └── widgets/
│       └── network_log_dialog.dart
├── android/
├── ios/
├── macos/
├── windows/
├── linux/
├── web/
├── test/
├── pubspec.yaml
└── 设计方案.md
```

### 1.2 核心功能

| 功能模块 | 入口文件 | 状态管理 | 网络层 |
|---------|---------|---------|--------|
| 文生图 | pages/generate/generate_page.dart | generate_provider.dart | ApiClient -> ImageService -> ImageRepository |
| 图编辑 | pages/edit/edit_page.dart | edit_provider.dart | ApiClient -> ImageService -> ImageRepository |
| 对话 | pages/chat/chat_page.dart | chat_provider.dart | ChatService（独立 Dio） |
| 设置 | pages/settings/settings_page.dart | settings_provider.dart | N/A |

---

## 二、现状诊断 —— 架构与代码级问题清单

### 2.1 入口与初始化（P0 严重）

**问题文件**：lib/main.dart

1. 初始化逻辑全部堆在 main.dart（L11-L51），SharedPreferences、通知服务、托盘、ProviderScope override 全部耦合在 main() 中。
2. 全局错误处理只做 debugPrint，没有统一错误上报。
3. _initializePlatformStatus 同时依赖 SharedPreferences 和 Platform 判断，职责不清。
4. Platform 判断硬编码在入口，增加新平台支持时需要修改多处。

**影响**：启动失败难以定位；增加平台或功能时需要改动核心入口。

---

### 2.2 状态管理（P0 严重）

#### 2.2.1 StateNotifier 持有 Ref 导致内存泄漏风险

**问题文件**：lib/providers/generate_provider.dart

```dart
class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _repository;
  final Ref _ref;  // 不应持有 Ref
```

Riverpod 官方不建议 StateNotifier 持有 Ref，因为 widget 销毁后 Ref 仍可能存活，造成内存泄漏。应改为在需要时通过 ref.read 临时读取。

#### 2.2.2 重复的状态定义模式

GenerateState、EditState、SettingsState 都有手写 copyWith，且实现不一致：
- EditState.copyWith 有 clearMask 参数
- SettingsState.copyWith 所有字段都支持为 null
- 缺少 == 和 hashCode，导致 Riverpod 不必要的重建

#### 2.2.3 Provider 中创建服务实例

**问题文件**：lib/providers/settings_provider.dart

- apiClientProvider、imageServiceProvider、imageRepositoryProvider、chatServiceProvider 全部在 settings_provider 中创建
- 职责耦合，settings_provider 既管理设置状态，又负责服务注册

#### 2.2.4 重复的生命周期处理

GeneratePage 和 EditPage 都实现了：
- WidgetsBindingObserver
- didChangeAppLifecycleState
- ForegroundService 调用
- NativeForegroundService 调用

代码重复率极高。

---

### 2.3 网络层（P1 高）

#### 2.3.1 ApiClient 与 ChatService 重复实现

**问题文件**：
- lib/services/api_client.dart
- lib/services/chat_service.dart

两者都实现了：
- 网络日志记录
- 超时配置
- 错误映射
- API Key 注入

但实现方式不同，维护成本高。

#### 2.3.2 切后台错误处理依赖字符串匹配

**问题文件**：
- lib/pages/generate/generate_page.dart L58
- lib/pages/edit/edit_page.dart L56

```dart
if (errorMsg.contains('连接') || errorMsg.contains('timeout') || errorMsg.contains('Socket'))
```

这种字符串匹配脆弱且不准确，应该基于错误码或 DioExceptionType 判断。

#### 2.3.3 ChatService 缺少统一错误映射

ChatService 只 rethrow DioException，没有像 ApiClient 那样映射为 AppException，导致上层无法统一处理。

#### 2.3.4 图片响应格式不一致

**问题文件**：lib/repositories/image_repository.dart

- generateImage 支持 b64_json 和 url 下载
- editImage 只支持 b64_json，如果 API 返回 url 会静默丢失结果（L78-L89）

---

### 2.4 平台能力抽象（P1 高）

#### 2.4.1 前台服务与通知混乱

**问题文件**：lib/utils/ 下多个文件

- foreground_service.dart
- native_foreground_service.dart
- notification_service.dart
- notification_service_nonweb.dart
- notification_service_web.dart

文件间关系不清晰，Platform 判断分散，缺少统一接口。

#### 2.4.2 系统托盘缺少统一抽象

**问题文件**：lib/utils/system_tray.dart

- 直接依赖 tray_manager
- 与页面耦合，通过 main.dart 初始化
- 缺少接口隔离

---

### 2.5 配置管理（P2 中）

#### 2.5.1 API 地址硬编码

**问题文件**：lib/config/api_config.dart

- defaultBaseUrl = 'https://jeniya.cn'
- chatBaseUrl = 'https://jeniya.top'

硬编码在多处，且 chatBaseUrl 与 defaultBaseUrl 的关系不明确。

#### 2.5.2 动态拼接 baseUrl

**问题文件**：lib/providers/settings_provider.dart L55

```dart
final baseUrl = (prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl)
    .replaceAll('/v1/images', '') + '/v1/chat';
```

通过字符串替换拼接 URL，脆弱且难以维护。

---

### 2.6 数据与缓存（P2 中）

#### 2.6.1 图片缓存为内存 LRU

**问题文件**：lib/repositories/image_repository.dart L94-L107

- 仅内存缓存，应用重启后丢失
- 没有持久化策略
- 缓存大小固定为 20，没有磁盘缓存兜底

#### 2.6.2 对话历史存储问题

**问题文件**：lib/providers/chat_provider.dart

- ChatHistoryStorage 每次都 await SharedPreferences.getInstance()（L48, L54, L69）
- 频繁 I/O，缺少防抖
- 存储格式为 JSON 字符串，没有版本管理

---

### 2.7 错误与体验（P2 中）

#### 2.7.1 异常处理不统一

- ApiClient 映射为 AppException
- ChatService 只 rethrow
- Provider 中混合 catch DioException 和 catch (e)
- UI 层直接显示 e.toString()，用户不友好

#### 2.7.2 空状态与错误状态重复

GeneratePage、EditPage、ChatPage 都有手写的空状态和错误状态组件，样式重复。

---

### 2.8 依赖与安全（P3 低）

#### 2.8.1 依赖版本检查

**问题文件**：pubspec.yaml

- workmanager: ^0.9.0+3（较旧）
- flutter_local_notifications: 18.0.0（锁定版本）
- window_manager: ^0.4.3（可能有新版本）

#### 2.8.2 缺少输入校验

- 提示词最大长度只在 UI 层通过 maxLength 限制
- API Key、URL 等输入没有格式校验

---

### 2.9 测试（P3 低）

- 仅 test/widget_test.dart
- 没有单元测试
- 没有集成测试
- 关键业务逻辑（生成、编辑、对话）无法自动化验证

---

## 三、Rework 目标与范围

### 3.1 目标

- 提升可维护性、可扩展性、可测试性
- 降低重复代码和耦合
- 统一跨端行为
- 保持现有业务功能不变

### 3.2 范围

- 架构重构：入口、初始化、配置管理
- 网络层统一：请求、响应、错误、日志
- 状态管理重构：统一状态模式、生命周期
- 平台能力抽象：前台服务、通知、托盘
- 数据持久化：图片缓存、对话历史
- 测试覆盖：单元测试、集成测试

---

## 四、分阶段改造计划 —— 详细代码级方案

### Phase 1：基础架构与状态管理重构（P0）

**目标**：解决入口混乱和状态管理问题，为后续重构奠定基础

#### 4.1.1 创建 AppBootstrap

**新增文件**：lib/core/bootstrap.dart

```dart
class AppBootstrap {
  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 1. 初始化核心服务
    final prefs = await SharedPreferences.getInstance();
    final errorHandler = AppErrorHandler();
    
    // 2. 注册全局错误处理
    FlutterError.onError = errorHandler.onFlutterError;
    await runZonedGuarded(() async {
      // 3. 初始化平台服务
      await PlatformServices.initialize(prefs);
      
      // 4. 启动应用
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const App(),
        ),
      );
    }, errorHandler.onZoneError);
  }
}
```

**修改文件**：lib/main.dart

```dart
void main() {
  AppBootstrap.run();
}
```

#### 4.1.2 统一状态基类

**新增文件**：lib/core/state/base_state.dart

```dart
sealed class OperationState<T> {
  const OperationState();
  
  const factory OperationState.idle() = IdleState<T>;
  const factory OperationState.loading({double? progress}) = LoadingState<T>;
  const factory OperationState.success(T data) = SuccessState<T>;
  const factory OperationState.error(String message, {Object? error}) = ErrorState<T>;
  
  bool get isLoading => this is LoadingState;
  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  });
}

class IdleState<T> implements OperationState<T> {
  const IdleState();
  @override
  R when<R>({...}) => idle();
}

class LoadingState<T> implements OperationState<T> {
  final double? progress;
  const LoadingState({this.progress});
  @override
  R when<R>({...}) => loading(progress);
}

class SuccessState<T> implements OperationState<T> {
  final T data;
  const SuccessState(this.data);
  @override
  R when<R>({...}) => success(data);
}

class ErrorState<T> implements OperationState<T> {
  final String message;
  final Object? error;
  const ErrorState(this.message, {this.error});
  @override
  R when<R>({...}) => error(message, error);
}
```

**改造 GenerateState**：

```dart
class GenerateState {
  final OperationState<List<ImageResult>> operation;
  final String prompt;
  final String model;
  final String size;
  final String format;
  final String quality;
  final int n;
  
  const GenerateState({
    this.operation = const OperationState.idle(),
    this.prompt = '',
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.format = 'jpeg',
    this.quality = 'medium',
    this.n = 1,
  });
  
  GenerateState copyWith({
    OperationState<List<ImageResult>>? operation,
    String? prompt,
    String? model,
    String? size,
    String? format,
    String? quality,
    int? n,
  }) {
    return GenerateState(
      operation: operation ?? this.operation,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      n: n ?? this.n,
    );
  }
  
  bool get isLoading => operation.isLoading;
  List<ImageResult>? get images => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (data) => data,
    error: (_, __) => null,
  );
  
  String? get errorMessage => operation.when(
    idle: () => null,
    loading: (_) => null,
    success: (_) => null,
    error: (message, _) => message,
  );
}
```

#### 4.1.3 修复 StateNotifier 持有 Ref 问题

**修改文件**：lib/providers/generate_provider.dart

```dart
class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _repository;
  CancelToken? _cancelToken;
  
  GenerateNotifier(this._repository) : super(const GenerateState()) {
    _loadDefaults();
  }
  
  void _loadDefaults() {
    // 不再持有 Ref，改为在需要时读取
    // 注意：这里需要重构为 FutureProvider 或在 build 时读取
  }
}
```

**问题**：_loadDefaults 需要读取 settingsProvider，但 StateNotifier 不应该持有 Ref。解决方案：
1. 改为在 UI 层读取 settings 后传入
2. 或使用 Provider.listen 在外部更新

**推荐方案 1**：

```dart
final generateProvider = StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  final repository = ref.watch(imageRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  return GenerateNotifier(repository, settings);
});

class GenerateNotifier extends StateNotifier<GenerateState> {
  final ImageRepository _repository;
  
  GenerateNotifier(this._repository, SettingsState settings)
      : super(GenerateState(
          model: settings.defaultModel,
          size: settings.defaultSize,
          n: settings.defaultCount,
        ));
}
```

---

### Phase 2：网络层统一化（P1）

**目标**：消除 ApiClient 和 ChatService 的重复代码，统一错误处理

#### 4.2.1 创建 BaseHttpClient

**新增文件**：lib/services/base_http_client.dart

```dart
class BaseHttpClient {
  late final Dio _dio;
  final NetworkLogCallback? onLog;
  final Map<String, DateTime> _requestTimestamps = {};
  
  BaseHttpClient({
    required String baseUrl,
    String? apiKey,
    this.onLog,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout ?? ApiConfig.connectTimeout,
      receiveTimeout: receiveTimeout ?? ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    if (apiKey != null && apiKey.isNotEmpty) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $apiKey';
          _logRequest(options);
          return handler.next(options);
        },
      ));
    }
    
    _setupLogging();
  }
  
  void _setupLogging() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logRequest(options);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logResponse(response);
        return handler.next(response);
      },
      onError: (error, handler) {
        _logError(error);
        return handler.next(error);
      },
    ));
  }
  
  void _logRequest(RequestOptions options) {
    final requestId = options.uri.toString();
    _requestTimestamps[requestId] = DateTime.now();
    onLog?.call(NetworkLog(
      id: requestId,
      type: NetworkLogType.request,
      timestamp: DateTime.now(),
      method: options.method,
      url: options.uri.toString(),
      headers: Map.from(options.headers),
      data: options.data,
    ));
  }
  
  void _logResponse(Response response) {
    final requestId = response.requestOptions.uri.toString();
    final startTime = _requestTimestamps.remove(requestId);
    final duration = startTime != null 
        ? DateTime.now().difference(startTime) 
        : null;
    onLog?.call(NetworkLog(
      id: requestId,
      type: NetworkLogType.response,
      timestamp: DateTime.now(),
      method: response.requestOptions.method,
      url: response.requestOptions.uri.toString(),
      statusCode: response.statusCode,
      data: response.data,
      duration: duration,
    ));
  }
  
  void _logError(DioException error) {
    final requestId = error.requestOptions.uri.toString();
    final startTime = _requestTimestamps.remove(requestId);
    final duration = startTime != null 
        ? DateTime.now().difference(startTime) 
        : null;
    onLog?.call(NetworkLog(
      id: requestId,
      type: NetworkLogType.error,
      timestamp: DateTime.now(),
      method: error.requestOptions.method,
      url: error.requestOptions.uri.toString(),
      statusCode: error.response?.statusCode,
      errorMessage: error.message,
      duration: duration,
    ));
  }
  
  Future<Response<T>> get<T>(String path, {...}) async {
    try {
      return await _dio.get<T>(path, ...);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<Response<T>> post<T>(String path, {...}) async {
    try {
      return await _dio.post<T>(path, ...);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<Response<T>> postFormData<T>(String path, {...}) async {
    try {
      return await _dio.post<T>(path, ...);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  AppException _handleError(DioException error) {
    // 统一错误映射逻辑
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('连接超时', code: 'TIMEOUT');
      // ... 其他错误类型
    }
  }
  
  void updateConfig({String? baseUrl, String? apiKey}) {
    if (baseUrl != null) _dio.options.baseUrl = baseUrl;
    // apiKey 更新需要重建 interceptor，建议重建客户端
  }
}
```

**改造 ApiClient**：

```dart
class ApiClient extends BaseHttpClient {
  ApiClient({String? baseUrl, String? apiKey, NetworkLogCallback? onLog})
      : super(
          baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl,
          apiKey: apiKey,
          onLog: onLog,
        );
  
  Future<Uint8List> downloadImage(String url, {...}) async {
    // 保留现有 downloadImage 逻辑，使用独立的 downloadDio
  }
}
```

**改造 ChatService**：

```dart
class ChatService extends BaseHttpClient {
  ChatService({String? baseUrl, String? apiKey, NetworkLogCallback? onLog})
      : super(
          baseUrl: baseUrl ?? ApiConfig.chatBaseUrl,
          apiKey: apiKey,
          onLog: onLog,
        );
  
  Future<ChatResponse> sendMessage({...}) async {
    // 直接使用 _dio，复用父类的日志和错误处理
  }
}
```

#### 4.2.2 统一错误分类

**新增文件**：lib/core/error/app_error.dart

```dart
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
  const ApiException(String message, {this.statusCode, String? code, Object? cause})
      : super(message, code: code, cause: cause);
  
  @override
  bool get isAuthError => statusCode == 401 || statusCode == 403;
}

class ValidationException extends AppError {
  const ValidationException(String message) : super(message);
}
```

#### 4.2.3 修复 editImage 不支持 URL

**修改文件**：lib/repositories/image_repository.dart

```dart
Future<List<ImageResult>> editImage({...}) async {
  final response = await _imageService.editImage(...);
  
  if (response.hasError) {
    throw ApiException(response.error ?? '编辑图片失败');
  }
  
  final results = <ImageResult>[];
  for (final imageData in response.data) {
    Uint8List? imageBytes;
    
    if (imageData.hasB64Json) {
      imageBytes = Uint8List.fromList(base64Decode(imageData.b64Json!));
    } else if (imageData.url != null && imageData.url!.isNotEmpty) {
      // 修复：支持 URL 下载
      imageBytes = await _apiClient.downloadImage(
        imageData.url!,
        cancelToken: cancelToken,
      );
    }
    
    if (imageBytes != null) {
      final result = ImageResult(...);
      results.add(result);
      _addToCache(result);
    }
  }
  
  return results;
}
```

---

### Phase 3：平台能力抽象（P2）

**目标**：统一前台服务、通知、托盘的接口

#### 4.3.1 前台服务接口

**新增文件**：lib/core/platform/foreground_service_interface.dart

```dart
abstract class IForegroundService {
  Future<void> start({required String title, String? body});
  Future<void> stop();
  Future<void> update({String? title, String? body});
  bool get isSupported;
}
```

**新增文件**：lib/core/platform/foreground_service_impl.dart

```dart
class ForegroundServiceImpl implements IForegroundService {
  final NativeForegroundService _nativeService;
  final NotificationService _notificationService;
  
  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  @override
  Future<void> start({required String title, String? body}) async {
    if (!isSupported) return;
    await _nativeService.start(title: title, body: body);
    await _notificationService.showGeneratingNotification(title, body);
  }
  
  @override
  Future<void> stop() async {
    if (!isSupported) return;
    await _nativeService.stop();
    await _notificationService.cancelGenerating();
  }
}
```

#### 4.3.2 系统托盘接口

**新增文件**：lib/core/platform/system_tray_interface.dart

```dart
abstract class ISystemTrayService {
  Future<void> initialize({
    VoidCallback? onOpenWindow,
    VoidCallback? onCancelTask,
    VoidCallback? onQuit,
  });
  Future<void> dispose();
  bool get isSupported;
}
```

---

### Phase 4：持久化与缓存增强（P3）

**目标**：为图片和对话历史增加持久化能力

#### 4.4.1 图片文件缓存

**新增文件**：lib/core/storage/image_storage.dart

```dart
class ImageStorage {
  final Directory _directory;
  final int maxCacheSizeMB;
  
  ImageStorage(this._directory, {this.maxCacheSizeMB = 500});
  
  Future<String> save(String id, Uint8List data) async {
    final file = File('${_directory.path}/$id.png');
    await file.writeAsBytes(data);
    return file.path;
  }
  
  Future<Uint8List?> load(String id) async {
    final file = File('${_directory.path}/$id.png');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
  
  Future<void> clear() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }
}
```

#### 4.4.2 对话历史防抖

**修改文件**：lib/providers/chat_provider.dart

```dart
class ChatNotifier extends StateNotifier<ChatState> {
  Timer? _saveTimer;
  
  Future<void> _scheduleSaveHistory() async {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveHistory();
    });
  }
  
  Future<void> sendMessage(String content) async {
    // ... 现有逻辑
    
    // 替换 await _saveHistory() 为
    _scheduleSaveHistory();
  }
}
```

---

### Phase 5：UI 组件统一（P4）

**目标**：提取通用组件，减少重复代码

#### 4.5.1 通用组件

**新增文件**：lib/widgets/common/

- empty_state.dart
- error_banner.dart
- confirm_dialog.dart
- result_grid.dart
- loading_indicator.dart

**示例**：empty_state.dart

```dart
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  
  const EmptyState({
    required this.icon,
    required this.title,
    this.description,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center),
          if (description != null) ...[
            SizedBox(height: 8),
            Text(description!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
```

#### 4.5.2 生命周期感知的 Mixin

**新增文件**：lib/core/mixins/background_operation_mixin.dart

```dart
mixin BackgroundOperationMixin<T extends StatefulWidget> on State<T> 
    implements WidgetsBindingObserver {
  
  final String operationTitle;
  final VoidCallback? onInterrupted;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 统一的后台/前台处理逻辑
  }
}
```

---

### Phase 6：测试覆盖（P5）

**目标**：建立基础测试框架，覆盖核心业务逻辑

#### 4.6.1 单元测试

**新增文件**：
- test/services/api_client_test.dart
- test/services/image_service_test.dart
- test/services/chat_service_test.dart
- test/providers/generate_provider_test.dart
- test/providers/settings_provider_test.dart

**示例**：api_client_test.dart

```dart
void main() {
  group('ApiClient', () {
    late ApiClient client;
    late MockDio mockDio;
    
    setUp(() {
      mockDio = MockDio();
      client = ApiClient(baseUrl: 'http://test.com', apiKey: 'test-key');
    });
    
    test('should return data on successful request', () async {
      // 测试逻辑
    });
    
    test('should throw NetworkException on timeout', () async {
      // 测试逻辑
    });
  });
}
```

#### 4.6.2 集成测试

**新增文件**：test/integration/

- generate_flow_test.dart
- edit_flow_test.dart
- chat_flow_test.dart

---

## 五、影响文件清单

### Phase 1 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| lib/main.dart | 重写 | 精简为调用 AppBootstrap.run() |
| lib/app.dart | 修改 | 移除初始化逻辑 |
| lib/providers/generate_provider.dart | 重构 | 移除 Ref 持有，使用 OperationState |
| lib/providers/edit_provider.dart | 重构 | 移除 Ref 持有，使用 OperationState |
| lib/core/bootstrap.dart | 新增 | 统一初始化入口 |
| lib/core/state/base_state.dart | 新增 | 统一状态基类 |

### Phase 2 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| lib/services/api_client.dart | 重构 | 继承 BaseHttpClient |
| lib/services/chat_service.dart | 重构 | 继承 BaseHttpClient |
| lib/services/base_http_client.dart | 新增 | 统一 HTTP 客户端基类 |
| lib/core/error/app_error.dart | 新增 | 统一异常体系 |
| lib/repositories/image_repository.dart | 修改 | 修复 editImage 不支持 URL |
| lib/config/api_config.dart | 修改 | 移除硬编码 URL，改为配置化 |

### Phase 3 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| lib/utils/foreground_service.dart | 重构 | 实现 IForegroundService |
| lib/utils/native_foreground_service.dart | 重构 | 实现 IForegroundService |
| lib/utils/notification_service.dart | 重构 | 实现 INotificationService |
| lib/utils/system_tray.dart | 重构 | 实现 ISystemTrayService |
| lib/core/platform/* | 新增 | 平台接口定义 |

### Phase 4 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| lib/repositories/image_repository.dart | 修改 | 添加文件缓存 |
| lib/providers/chat_provider.dart | 修改 | 添加保存防抖 |
| lib/core/storage/image_storage.dart | 新增 | 图片文件存储 |

### Phase 5 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| lib/pages/generate/generate_page.dart | 重构 | 使用通用组件 |
| lib/pages/edit/edit_page.dart | 重构 | 使用通用组件 |
| lib/pages/chat/chat_page.dart | 重构 | 使用通用组件 |
| lib/widgets/common/* | 新增 | 通用组件库 |

### Phase 6 影响文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| test/services/* | 新增 | 服务层单元测试 |
| test/providers/* | 新增 | Provider 单元测试 |
| test/integration/* | 新增 | 集成测试 |

---

## 六、回归测试 Checklist

### Phase 1 完成后

- [ ] 应用正常启动，无崩溃
- [ ] 设置页面可正常打开和保存
- [ ] 文生图页面可正常输入提示词
- [ ] 图编辑页面可正常选择图片
- [ ] 对话页面可正常发送消息
- [ ] 网络日志弹窗可正常打开
- [ ] 系统托盘功能正常（Windows/Mac/Linux）
- [ ] 前台通知功能正常（Android/iOS）

### Phase 2 完成后

- [ ] 文生图流程端到端正常
- [ ] 图编辑流程端到端正常
- [ ] 对话流程端到端正常
- [ ] 网络错误正确映射为用户友好提示
- [ ] 取消请求后状态正确恢复
- [ ] 切后台后恢复前台时状态正确

### Phase 3 完成后

- [ ] 前台保活在后台持续
- [ ] 通知点击可打开应用
- [ ] 托盘菜单功能正常
- [ ] Web 平台不调用原生 API

### Phase 4 完成后

- [ ] 图片生成后重启应用仍可显示
- [ ] 对话历史重启后保留
- [ ] 缓存大小限制生效
- [ ] 保存图片到相册功能正常

### Phase 5 完成后

- [ ] UI 在亮色/暗色模式下均正常
- [ ] 空状态显示正确
- [ ] 错误状态显示正确
- [ ] 加载状态显示正确
- [ ] 交互响应及时

---

## 七、依赖升级计划

### 7.1 建议升级的依赖

| 包名 | 当前版本 | 建议版本 | 原因 |
|------|---------|---------|------|
| dio | ^5.8.0 | ^5.7.0 | 检查是否有安全更新 |
| flutter_riverpod | ^2.6.1 | ^2.5.1 | 检查 Riverpod 最新版本 |
| image_picker | ^1.1.2 | ^1.1.2 | 当前版本较新，保持 |
| file_picker | ^8.1.7 | ^8.1.7 | 保持 |
| shared_preferences | ^2.5.3 | ^2.3.3 | 保持 |
| path_provider | ^2.1.4 | ^2.1.4 | 保持 |
| gal | ^2.3.0 | ^2.3.0 | 保持 |
| cached_network_image | ^3.4.1 | ^3.4.1 | 保持 |
| permission_handler | ^12.0.3 | ^12.0.3 | 保持 |
| workmanager | ^0.9.0+3 | ^0.9.0+3 | 较旧，检查是否有更新 |
| flutter_local_notifications | 18.0.0 | 18.0.0 | 保持 |
| tray_manager | ^0.2.3 | ^0.2.3 | 保持 |
| window_manager | ^0.4.3 | ^0.4.3 | 保持 |

### 7.2 建议新增的依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| freezed | ^2.5.0 | 数据类生成 |
| json_annotation | ^4.9.0 | JSON 序列化 |
| build_runner | ^2.4.0 | 代码生成 |
| flutter_cache_manager | ^3.3.0 | 图片缓存 |
| mocktail | ^1.0.0 | 测试 mock |

---

## 八、回滚策略

### 8.1 版本控制

- 每个 Phase 完成后创建一个 git tag：`v1.0.0-phase1`
- 使用特性分支：`feature/phase1-bootstrap`
- 合并到 main 前确保所有测试通过

### 8.2 回滚步骤

如果某个 Phase 出现问题：

1. **立即回滚**：`git revert` 到上一个 phase tag
2. **保留改动**：创建新分支 `hotfix/phaseX-issue` 用于修复
3. **分析原因**：在回滚分支上重现问题
4. **重新实施**：修复后重新合并

### 8.3 渐进式回滚

如果问题只影响特定功能：
1. 使用特性开关控制新旧代码
2. 默认使用旧实现
3. 逐步切换到新实现

---

## 九、执行建议

### 9.1 执行顺序

1. **Phase 1**（基础架构）是最优先的，解决内存泄漏和状态管理问题
2. **Phase 2**（网络层）紧随其后，统一错误处理
3. **Phase 3-5** 可以并行推进，按平台能力、持久化、UI 顺序
4. **Phase 6**（测试）贯穿始终，每个 Phase 完成后补充对应测试

### 9.2 风险控制

- 每个 Phase 控制在 1-2 周内完成
- 完成后立即进行回归测试
- 使用 git tag 保存每个 Phase 的稳定版本
- 重大问题及时回滚，不要勉强推进

### 9.3 下一步行动

1. 确认本报告方案
2. 从 Phase 1 开始实施
3. 先重构 main.dart 和 AppBootstrap
4. 然后重构状态管理
5. 逐步推进到后续 Phase

---

## 附录：关键代码问题速查

### A.1 内存泄漏风险点

| 位置 | 问题 |
|------|------|
| lib/providers/generate_provider.dart L74 | StateNotifier 持有 Ref |
| lib/providers/edit_provider.dart | 同上 |

### A.2 重复代码

| 重复逻辑 | 涉及文件 |
|---------|---------|
| 生命周期监听 | generate_page.dart, edit_page.dart |
| 空状态组件 | generate_page.dart, edit_page.dart, chat_page.dart |
| 错误状态组件 | generate_page.dart, edit_page.dart |
| 网络日志记录 | api_client.dart, chat_service.dart |

### A.3 硬编码与魔法值

| 位置 | 硬编码值 |
|------|---------|
| lib/config/api_config.dart L5 | 'https://jeniya.cn' |
| lib/config/api_config.dart L54 | 'https://jeniya.top' |
| lib/providers/settings_provider.dart L55 | 字符串拼接 URL |
| lib/pages/generate/generate_page.dart L50 | '连接' 错误判断 |
| lib/pages/edit/edit_page.dart L56 | '连接' 错误判断 |

---

**报告结束**
