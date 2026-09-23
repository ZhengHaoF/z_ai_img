# Z Ai - Code Wiki 文档

## 1. 项目概述

**Z Ai** 是一个基于 Flutter 构建的跨平台 AI 图像生成与编辑应用。支持 Android、Windows 双端运行。

### 核心功能

| 功能 | 说明 |
|------|------|
| 文生图 | 输入文字描述，AI 根据描述生成对应图片 |
| 图编辑 | 上传一张或多张图片，输入编辑描述，AI 对图片进行编辑修改 |
| 大图预览 | 点击生成/编辑结果进入全屏预览，支持缩放、保存 |
| 网络调试 | 内置网络日志面板，方便调试 API 请求与响应 |

---

## 2. 技术栈

| 技术 | 版本/说明 |
|------|----------|
| 框架 | Flutter SDK ^3.12.2 |
| 语言 | Dart |
| 状态管理 | flutter_riverpod ^2.6.1 |
| 网络请求 | dio ^5.8.0 |
| 本地存储 | shared_preferences ^2.5.3 |
| 图片处理 | image_picker ^1.1.2, file_picker ^8.1.7, gal ^2.3.0 |
| 平台通知 | flutter_local_notifications ^18.0.0 |
| 桌面托盘 | tray_manager ^0.2.3 |
| 权限处理 | permission_handler ^12.0.3 |

---

## 3. 项目目录结构

```
z_ai_img/
├── android/                    # Android 平台配置
│   ├── app/src/main/           # Android 原生代码
│   │   ├── kotlin/com/zai/app/ # 前台服务 (GenerateForegroundService.kt)
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts        # Gradle 构建配置
├── windows/                    # Windows 平台配置
├── lib/                        # ★ 核心业务代码
│   ├── main.dart               # 应用入口
│   ├── app.dart                # MaterialApp + 主题配置
│   ├── config/
│   │   ├── api_config.dart     # API 地址、端点、默认参数、常量
│   │   └── themes.dart         # 主题配置（Light/Dark）
│   ├── core/
│   │   ├── bootstrap.dart      # 应用启动初始化
│   │   ├── network/
│   │   │   └── base_http_client.dart  # HTTP 客户端封装（dio + 日志拦截）
│   │   ├── platform/
│   │   │   ├── platform_capabilities.dart       # 平台能力检测
│   │   │   ├── foreground_service_interface.dart # 前台服务接口
│   │   │   ├── foreground_service_impl.dart      # 前台服务实现
│   │   │   ├── system_tray_interface.dart        # 系统托盘接口
│   │   │   └── system_tray_impl.dart             # 系统托盘实现
│   │   └── storage/
│   │       └── image_storage.dart       # 图片文件缓存（LRU 淘汰）
│   ├── exceptions/
│   │   └── app_exception.dart            # 应用异常层次
│   ├── models/
│   │   ├── image_result.dart             # 图片结果模型
│   │   ├── network_log.dart              # 网络日志模型
│   │   ├── edit/edit_request.dart        # 图编辑请求模型
│   │   ├── edit/edit_response.dart       # 图编辑响应模型
│   │   └── generate/generate_request.dart    # 文生图请求模型
│   │       generate_response.dart           # 文生图响应模型
│   ├── providers/
│   │   ├── settings_provider.dart        # 全局设置 + 服务层 providers
│   │   ├── generate_provider.dart        # 文生图状态管理
│   │   ├── edit_provider.dart            # 图编辑状态管理
│   │   └── network_log_provider.dart     # 网络日志状态管理
│   ├── services/
│   │   ├── api_client.dart               # HTTP 客户端（dio 封装）
│   │   └── image_service.dart            # 图片 API 服务
│   ├── repositories/
│   │   └── image_repository.dart         # 图片数据转换 + 错误封装 + LRU 缓存
│   ├── pages/
│   │   ├── home_page.dart                # 主页（底部导航 + 页面切换 + AppBar）
│   │   ├── generate/generate_page.dart   # 文生图页面
│   │   ├── edit/edit_page.dart           # 图编辑页面
│   │   ├── preview/image_preview_page.dart  # 大图预览页
│   │   └── settings/settings_page.dart   # 设置页面
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── error_banner.dart         # 错误提示横幅
│   │   │   ├── result_grid.dart          # 图片结果网格
│   │   │   └── ...
│   │   └── params/                       # 参数配置组件
│   │       ├── model_selector.dart
│   │       ├── prompt_field.dart
│   │       ├── size_count_selector.dart
│   │       └── submit_button.dart
│   ├── utils/
│   │   ├── background_error.dart         # 后台中断错误判定
│   │   ├── image_utils.dart              # 图片选择 / 保存工具
│   │   ├── validators.dart               # 表单验证
│   │   ├── foreground_service.dart       # 前台通知服务
│   │   ├── native_foreground_service.dart # Android 前台服务桥接
│   │   └── system_tray.dart              # 系统托盘管理器
├── test/
│   └── integration/                      # 集成测试
├── pubspec.yaml                          # 项目依赖配置
├── README.md                             # 项目说明
└── 设计方案.md                            # 详细设计方案文档
```

---

## 4. 整体架构

### 4.1 架构概览

项目采用 **分层架构** + **Riverpod 状态管理** 的设计模式，整体遵循 Clean Architecture 原则：

```
┌─────────────────────────────────────────────────────────┐
│                        UI 层 (Pages + Widgets)           │
│     展示与用户交互，触发事件通知 Provider                  │
├─────────────────────────────────────────────────────────┤
│                     状态管理层 (Providers)                │
│     StateNotifier 管理页面状态，调用 Repository           │
├─────────────────────────────────────────────────────────┤
│                    数据层 (Repositories)                 │
│     数据转换、错误封装、LRU 缓存、请求取消                │
├─────────────────────────────────────────────────────────┤
│                    服务层 (Services)                      │
│     HTTP 调用、API 对接、基础解析                         │
├─────────────────────────────────────────────────────────┤
│                   网络层 (HTTP Clients)                   │
│     Dio 封装、拦截器、日志记录                            │
├─────────────────────────────────────────────────────────┤
│                   模型层 (Models)                         │
│     请求/响应数据模型、序列化/反序列化                     │
├─────────────────────────────────────────────────────────┤
│                   本地存储 (Storage)                      │
│     SharedPreferences、文件缓存                          │
└─────────────────────────────────────────────────────────┘
```

### 4.2 数据流

```
UI (Page) → Provider → Repository → Service → HTTP Client → API
                                                              ↓
UI ← Provider ← Repository ← Service ← HTTP Client ← API
      业务模型       数据转换      原始响应
```

各层职责：

| 层级 | 职责 | 数据格式 |
|------|------|----------|
| **UI (Page)** | 展示、交互 | Widget / UI State |
| **Provider** | 页面状态管理 + 通知服务 | 业务模型（如 `List<ImageResult>`） |
| **Repository** | 数据转换、错误封装、缓存、取消 | 业务模型（`ImageResult`、`AppException`） |
| **Service** | HTTP 调用、基础解析 | 原始请求/响应模型 |
| **API** | 远端服务 | JSON |

---

## 5. 主要模块详解

### 5.1 应用启动模块

**入口文件**: [main.dart](d:\work\z_ai_img\lib\main.dart)

```dart
void main() {
  AppBootstrap.run();
}
```

**启动流程**:
1. 确保 Flutter 绑定初始化 (`WidgetsFlutterBinding.ensureInitialized()`)
2. 注册全局 Flutter 错误处理器
3. 使用 `runZonedGuarded` 包裹整个初始化流程
4. 获取 `SharedPreferences` 实例
5. 初始化前台通知服务权限（仅 Android）
6. 初始化桌面系统托盘（仅桌面端且用户已开启）
7. 启动 `ProviderScope` + `App` 组件

### 5.2 配置模块

#### [ApiConfig](d:\work\z_ai_img\lib\config\api_config.dart)

应用的核心配置类，包含：

**`ApiProfile`** - API 配置集（支持多配置）:
- `id` - 配置唯一标识
- `name` - 配置名称
- `apiKey` - API 密钥
- `baseUrl` - 图片生成/编辑 API 地址
- `defaultModel` - 默认生成模型（默认 `gpt-image-2`）
- `defaultSize` - 默认图片尺寸（默认 `1024x1024`）
- `defaultCount` - 默认生成数量（默认 1）

**`ApiConfig`** - 全局配置常量:
- 超时: 连接 30s，接收 10min
- 支持的图片尺寸: 8 种尺寸（1024x1024 ~ 3840x2160）
- 模型选项: 文生图 `gpt-image-2` / `z-image-turbo`
- 缓存上限: 20 张图片
- 持久化存储 Key

#### [Themes](d:\work\z_ai_img\lib\config\themes.dart)

提供 Material 3 主题配置：
- `lightTheme` - 浅色主题（deepPurple 基色）
- `darkTheme` - 深色主题
- 统一配置: AppBar、Card、Button、InputDecoration、ExpansionTile

### 5.3 异常处理模块

**层次结构**:

```
AppException (abstract)
├── NetworkException  - 网络层异常
├── ApiException      - API 业务异常（含 statusCode、code）
├── ValidationException - 参数验证异常
├── CancelException    - 请求取消异常
└── CacheException     - 缓存异常
```

**使用方式**:
- Repository 层捕获网络异常，统一封装为 `AppException`
- Provider 层根据异常类型做差异化 UI 处理
- `CancelException` 不展示错误横幅

### 5.4 模型层 (Models)

#### [ImageResult](d:\work\z_ai_img\lib\models\image_result.dart)

```dart
class ImageResult {
  String id;
  Uint8List imageData;      // 图片二进制数据
  int? width;               // 图片宽度
  int? height;              // 图片高度
  DateTime createdAt;       // 创建时间
  String? prompt;           // 生成提示词
  String sizeLabel;         // 尺寸标签 "1024x1024"
}
```

#### 文生图模型

- **[GenerateRequest]**: `model`, `prompt`, `n`, `size`, `quality`, `format`
- **[GenerateResponse]**: 解析 API 响应，支持两种格式：
  - 标准格式: `data[].b64_json`
  - 兜底格式: `choices[].message.content`

#### 图编辑模型

- **[EditRequest]**: `images`(多图), `prompt`, `mask`(可选遮罩), `model`, `n`, `size`, `quality`, `background`, `moderation`
- **[EditResponse]**: 同 GenerateResponse 结构

### 5.5 网络层

#### [ApiClient](d:\work\z_ai_img\lib\services\api_client.dart)

继承自 `BaseHttpClient`，提供：
- 统一的 `Authorization: Bearer {{apiKey}}` 认证
- `updateConfig(baseUrl, apiKey)` - 运行时动态更新配置
- 网络日志回调 `onLog`

#### [BaseHttpClient](d:\work\z_ai_img\lib\core\network\base_http_client.dart)

基于 Dio 封装的通用 HTTP 客户端：
- 统一的拦截器（认证、日志记录）
- 全局错误处理 → 统一异常类型
- 超时配置
- 独立 download Dio 实例（用于下载图片）

#### [ImageService](d:\work\z_ai_img\lib\services\image_service.dart)

- `generateImage(request, cancelToken)` → POST `/v1/images/generations`
- `editImage(request, cancelToken, onSendProgress)` → POST `/v1/images/edits` (multipart/form-data)

### 5.6 Repository 层

#### [ImageRepository](d:\work\z_ai_img\lib\repositories\image_repository.dart)

核心数据适配与缓存层：

**`generateImage()`**:
1. 调用 `ImageService.generateImage()`
2. 解析响应（优先 `data[].b64_json`，兜底 URL 下载）
3. base64 解码 → `Uint8List`
4. 构建 `ImageResult` 对象
5. 存入内存 LRU 缓存 + 文件缓存

**`editImage()`**: 流程同上，但使用 multipart 上传

**LRU 缓存策略**:
- 内存缓存: 最多 20 张（`maxImageCacheSize = 20`）
- 文件缓存: 通过 `ImageStorage` 持久化，超出 500MB 自动淘汰最旧文件

### 5.7 状态管理模块 (Providers)

#### [SettingsProvider](d:\work\z_ai_img\lib\providers\settings_provider.dart)

全局设置管理，同时提供依赖注入：

**`SettingsState`**:
- `apiProfiles` - API 配置集列表
- `activeProfileId` - 当前激活配置
- `isDarkMode` - 深色模式
- `showTrayIcon` - 显示托盘图标

**核心 Provider 链路**:
```
sharedPreferencesProvider (继承值注入)
    ↓
settingsProvider (全局设置)
    ↓
apiClientProvider (HttpClient)
    ↓
imageServiceProvider
    ↓
imageRepositoryProvider
    ↓
generateProvider / editProvider
```

**性能优化**:
- `apiClientProvider` 只监听 `activeProfile 的 (baseUrl, apiKey)` 组合，避免无关设置变更触发级联重建
- 使用 `.select()` 精确追踪所需字段

#### [GenerateProvider](d:\_work\z_ai_img\lib\providers\generate_provider.dart)

**`GenerateState`**: `images`, `isLoading`, `error`, `prompt`

**`generateImage()`** 流程:
1. 验证提示词不为空
2. 从当前配置获取模型/尺寸/数量
3. 设置 loading 状态
4. 启动 Android 前台服务保活
5. 构建 `GenerateRequest` → 调用 Repository
6. 成功 → 追加到 images 列表
7. 失败 → 展示错误（CancelException 例外）
8. 无论结果如何，最终停止前台服务

#### [EditProvider](d:\work\z_ai_img\lib\providers\edit_provider.dart)

**`EditState`**: `images`, `isLoading`, `error`, `prompt`, `selectedImagePaths`, `maskImagePath`, `selectedImages`, `maskImage`

提供图片选择/遮罩管理方法：
- `pickSourceImages()` - 多选源图片
- `pickMaskImage()` - 选择遮罩
- `clearSourceImages()` / `clearMaskImage()` - 清空选择
- `editImage()` - 执行编辑（流程同 generate）

### 5.8 平台适配模块

#### [PlatformCapabilities](d:\work\z_ai_img\lib\core\platform\platform_capabilities.dart)

平台能力检测：

| 能力 | 判断逻辑 |
|------|---------|
| 系统托盘 | `isDesktop`（即 `Platform.isWindows`） |
| 前台服务 | `Android` |

> 项目仅支持 Android / Windows，故没有 `isWeb` / `isIOS` / `isMacOS` / `isLinux` 之类的判断。

#### [NativeForegroundService](d:\work\z_ai_img\lib\utils\native_foreground_service.dart)

通过 MethodChannel (`com.zai.app/foreground`) 桥接 Android 原生 `GenerateForegroundService.kt`：
- `start(title, body)` - 启动前台服务
- `stop()` - 停止前台服务

#### [ImageUtils](d:\work\z_ai_img\lib\utils\image_utils.dart)

图片工具（仅支持 Android / Windows）：
- 选择图片: 移动端使用 `image_picker`（相册/相机）；桌面端另有 `file_picker` 可从文件系统选取
- 图片保存: 移动端写入系统相册（`gal`）；桌面端暂不支持，返回 `false`

### 5.9 存储模块

#### [ImageStorage](d:\work\z_ai_img\lib\core\storage\image_storage.dart)

文件缓存管理器：
- `save(id, data)` - 保存图片到文件（父目录不存在时会自动创建）
- `load(id)` - 从文件加载图片
- `clear()` - 清除所有缓存
- **LRU 淘汰**: 文件修改时间最早上传的最先删除，直到总大小 ≤ 500MB

> 存储目录由 `AppBootstrap._resolveImageCacheDirectory()` 在启动时解析
> （`getApplicationSupportDirectory()/image_cache`，无 path_provider 的环境回退到系统临时目录），
> 再通过 `imageStorageProvider` 注入；默认实现会抛错，避免退化成无效路径。

### 5.10 UI 模块

#### [HomePage](d:\work\z_ai_img\lib\pages\home_page.dart)

主页面，采用 `IndexedStack` + `NavigationBar` 架构：

- Tab 0: `GeneratePage`（文生图）
- Tab 1: `EditPage`（图编辑）
- 右上角: 网络日志 `NetworkLogDialog`、设置页 `SettingsPage`

视觉效果:
- 玻璃态导航栏（`BackdropFilter` + `withValues` alpha）
- Tab 切换动画（`FadeTransition` + `SlideTransition`）
- 选中态图标缩放动画（`AnimatedScale`）

#### 页面状态模式

所有功能页面遵循统一的状态构成：

| 状态 | 表现 |
|------|------|
| **空状态** | 占位图 + AI 引导文案 |
| **加载中** | 按钮禁用 + 顶部进度提示 + 取消按钮 |
| **成功** | 结果展示（GridView 图片网格） |
| **错误** | 错误横幅 + 保留历史结果 |

#### 设置页面

分为五个区块:
- `ApiConfigSection` - API 配置集管理（新增/切换/删除）
- `AppearanceSection` - 深色模式切换
- `TraySection` - 托盘图标开关
- `DataSection` - 清除设置
- `AboutSection` - 关于

---

## 6. 核心类与函数速查

### 6.1 配置类

| 类 | 文件 | 关键方法 |
|----|------|---------|
| `ApiConfig` | config/api_config.dart | `defaultProfile()`, 常量集合 |
| `ApiProfile` | config/api_config.dart | `copyWith()`, `toJson()`, `fromJson()` |
| `AppTheme` | config/themes.dart | `lightTheme`, `darkTheme` |

### 6.2 业务模型类

| 类 | 文件 | 关键属性 |
|----|------|---------|
| `ImageResult` | models/image_result.dart | `imageData`, `prompt`, `sizeLabel` |
| `GenerateRequest` | models/generate/generate_request.dart | `model`, `prompt`, `n`, `size`, `quality`, `format` |
| `GenerateResponse` | models/generate/generate_response.dart | `data`, `error`, `fromJson()`, `fromChoices()` |
| `ImageData` | models/generate/generate_response.dart | `b64Json`, `url`, `revisedPrompt`, `hasB64Json` |
| `EditRequest` | models/edit/edit_request.dart | `images`, `prompt`, `mask`, `model`, `n`, `size` |
| `EditResponse` | models/edit/edit_response.dart | 继承 GenerateResponse 结构 |

### 6.3  Provider 类

| Provider | 文件 | 状态类 | 核心方法 |
|---------|------|--------|---------|
| `generateProvider` | providers/generate_provider.dart | `GenerateState` | `generateImage()`, `clearResults()` |
| `editProvider` | providers/edit_provider.dart | `EditState` | `editImage()`, `pickSourceImages()`, `pickMaskImage()` |
| `settingsProvider` | providers/settings_provider.dart | `SettingsState` | `setApiKey()`, `setBaseUrl()`, `addProfile()`, `removeProfile()` |
| `networkLogProvider` | providers/network_log_provider.dart | - | `addLog()` |

### 6.4 Service 类

| 类 | 文件 | 核心方法 |
|----|------|---------|
| `ImageService` | services/image_service.dart | `generateImage()`, `editImage()` |
| `ApiClient` | services/api_client.dart | `updateConfig()`, 继承 `BaseHttpClient` |

### 6.5 Repository 类

| 类 | 文件 | 核心方法 |
|----|------|---------|
| `ImageRepository` | repositories/image_repository.dart | `generateImage()`, `editImage()`, `clearCache()` |

---

## 7. API 端点说明

| 功能 | 方法 | 地址 | Content-Type |
|------|------|------|-------------|
| 文生图 | POST | `/v1/images/generations` | `application/json` |
| 图编辑 | POST | `/v1/images/edits` | `multipart/form-data` |

**认证**: 所有请求 Header 携带 `Authorization: Bearer {{API_KEY}}`

**超时配置**: 连接 30s，接收 10min

### 文生图请求体

```json
{
  "model": "gpt-image-2",
  "prompt": "描述文字",
  "n": 1,
  "size": "1024x1024",
  "quality": "auto",
  "format": "png"
}
```

### 图编辑请求体 (multipart)

```
image: <file[]>    (必填，多文件)
mask: <file>       (可选)
prompt: "编辑描述" (必填)
model: "gpt-image-2" (可选)
n: "1"             (可选)
size: "1024x1536"  (可选)
```

---

## 8. 依赖关系图

```
┌──────────────────────────────────────────────────────────┐
│                     widgets/ (UI 组件)                     │
│     ┌──────────────────────────────────────┐              │
│     │    pages/ (页面层)                    │              │
│     │    depends on providers/             │              │
│     └──────────────┬───────────────────────┘              │
└────────────────────┼──────────────────────────────────────┘
                     │ watch/read
                     ▼
┌──────────────────────────────────────────────────────────┐
│               providers/ (状态管理层)                      │
│  settingsProvider ├── apiClientProvider                   │
│                     │    └── imageServiceProvider         │
│                     ├── imageRepositoryProvider           │
│                     └── networkLogProvider                │
│                                                           │
│  generateProvider └── depends on imageRepositoryProvider  │
│  editProvider─────── depends on imageRepositoryProvider   │
└──────────────────────────────────────────────────────────┘
                     │ uses
        ┌────────────┴───────────────┐
        ▼                            ▼
┌──────────────────┐      ┌──────────────────┐
│ repositories/    │      │   services/      │
│ imageRepository  │      │ ├── ImageService  │
│                   │      │ └── ApiClient     │
│ · data transform │      │                   │
│ · LRU cache      │      │   (extends        │
│ · error wrap     │      │    BaseHttpClient) │
└────────┬──────────┘      └────────┬──────────┘
         │                          │
         └──────────┬───────────────┘
                    ▼
         ┌─────────────────┐
         │  dio (HTTP)      │
         └─────────────────┘
                    │
                    ▼
         ┌─────────────────┐
         │  External APIs   │
         └─────────────────┘
```

---

## 9. 关键设计模式与优化

### 9.1 Provider 依赖注入优化

`apiClientProvider` 使用 `settingsProvider.select()` 仅监听 `(baseUrl, apiKey)` 组合：
- 修改主题、托盘设置等无关配置时，不会重建 HttpClient
- 避免级联重建整棵业务树
- 保留已生成的图片和聊天记录

### 9.2 请求取消机制

所有 Provider 在发起请求时创建 `CancelToken`:
- 用户手动取消 → 抛出 `CancelException` → 静默结束 loading
- 切换 Tab 时保留页面状态，不中断后台请求
- `ref.onDispose()` 自动清理 Dio 实例

### 9.3 网络日志系统

`ApiClient` 通过 `onLog` 回调将请求/响应信息推送到 `NetworkLogProvider`:
- 完整的请求方法、URL、Headers（自动脱敏）、Body
- 响应状态码、数据、耗时
- 错误信息和错误码
- 最多保留 100 条日志
- 可在首页通过调试图标弹出查看

### 9.4 多层缓存策略

| 层级 | 内容 | 存储方式 | 有效期 |
|------|------|----------|--------|
| 内存缓存 | 生成的图片 `Uint8List` | LRU Map（最多 20 张） | 应用会话期内 |
| 文件缓存 | 生成的图片文件 | 本地应用目录（< 500MB 自动淘汰） | 持久化 |
| 本地存储 | API 配置集 | `shared_preferences` (JSON) | 持久化 |

### 9.5 平台适配

通过 `PlatformCapabilities` 抽象各平台能力，业务代码根据能力开关适配行为：

```dart
if (PlatformCapabilities.isDesktop) { ... }
if (PlatformCapabilities.supportsSystemTray) { ... }
if (PlatformCapabilities.supportsForegroundService) { ... }
```

### 9.6 前台服务保活

Android 端通过 `MethodChannel` 桥接原生 `GenerateForegroundService.kt`，在生成/编辑进行中保持前台通知，防止系统杀后台。

---

## 10. 项目运行方式

### 10.1 环境要求

- Flutter SDK 3.12.2+
- Dart SDK 3.12.2+
- 各平台对应 SDK（Android 需 Android Studio，Windows 需 Visual Studio）

### 10.2 安装依赖

```powershell
flutter pub get
```

### 10.3 运行应用

```powershell
# 自动检测平台运行
flutter run

# 指定平台运行
flutter run -d windows
flutter run -d emulator-5554  # Android 模拟器
```

### 10.4 构建发布版本

```powershell
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Windows
flutter build windows --release
```

### 10.5 首次配置

1. 启动应用后点击右上角设置图标
2. 输入 API Key 和 Base URL（图片 API 默认 `https://jeniya.cn`）
3. 支持多个配置集，可随时切换

### 10.6 运行测试

```powershell
# 运行所有测试
flutter test

# 特定测试
flutter test test/integration/app_bootstrap_test.dart
```

---

## 11. 代码规范与注意

- 遵循 Flutter/Dart 官方 lint 规范（`flutter_lints ^6.0.0`）
- 样式分析已配置于 `analysis_options.yaml`
- 所有异步操作使用 `async/await`，统一错误处理
- 敏感信息（API Key）存储在 `SharedPreferences`，不硬编码
- 网络日志自动脱敏敏感 Header

---

## 12. 已知限制与未来扩展

### 限制

- Mobile 端图片选择仅支持 image_picker（不直接暴露文件系统选择器）
- Windows 端使用 `libcurl` 网络库（特定依赖）

### 未来扩展方向

- 历史记录（保存每次生成/编辑记录 + 搜索）
- 风格预设（提示词模板）
- 批量生成（多组参数组合）
- 图片变体（多种风格变体）
- 国际化（多语言）
- 编辑历史（撤销/重做）
