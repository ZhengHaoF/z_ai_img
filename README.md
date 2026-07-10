# Z Ai

**Z Ai** 是一个基于 Flutter 构建的跨平台 AI 图像生成与编辑应用，同时内置 AI 对话功能。支持 iOS、Android、Web、macOS、Windows、Linux 六端运行。

## 核心功能

| 功能 | 说明 |
|------|------|
| 文生图 | 输入文字描述，AI 根据描述生成对应图片 |
| 图编辑 | 上传一张或多张图片，输入编辑描述，AI 对图片进行编辑修改 |
| AI 对话 | 与 AI 进行文字交流，支持对话历史持久化 |
| 大图预览 | 点击生成/编辑结果进入全屏预览，支持缩放、保存 |
| 网络调试 | 内置网络日志面板，方便调试 API 请求与响应 |

## 技术栈

- **框架**: Flutter (SDK ^3.12.2)
- **语言**: Dart
- **状态管理**: flutter_riverpod ^2.6.1
- **网络请求**: dio ^5.8.0
- **本地存储**: shared_preferences ^2.5.3
- **图片处理**: image_picker ^1.1.2, file_picker ^8.1.7, gal ^2.3.0
- **平台通知**: flutter_local_notifications ^18.0.0
- **桌面托盘**: tray_manager ^0.2.3, window_manager ^0.4.3

## 支持的平台

| 平台 | 支持情况 |
|------|----------|
| Android | 完整支持（含前台服务通知） |
| iOS | 完整支持（含前台服务通知） |
| Web | 支持（通知使用浏览器 Notification API，图片下载到本地） |
| macOS | 支持（系统托盘） |
| Windows | 支持（系统托盘 + 窗口管理） |
| Linux | 支持（系统托盘） |

## 快速开始

### 环境要求

- Flutter SDK 3.12.2 或更高版本
- Dart SDK 3.12.2 或更高版本

### 安装依赖

```bash
flutter pub get
```

### 配置 API Key

首次运行需要配置 API Key。应用启动后点击右上角「设置」图标，进入设置页面：
- **API Key**: 输入你的 API Key
- **Base URL**: 图片生成/编辑 API 地址（默认 `https://jeniya.cn`）
- **对话 Base URL**: AI 对话 API 地址（可选，默认自动从 Base URL 推导）

### 运行应用

```bash
# 选择目标平台运行
flutter run
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## 目录结构

```
lib/
 ├── main.dart                          # 应用入口
 ├── app.dart                           # MaterialApp + 主题配置
 ├── config/
 │    ├── api_config.dart               # API 地址、端点、默认参数、常量
 │    └── themes.dart                   # 主题配置（Light/Dark）
 ├── core/
 │    ├── bootstrap.dart                # 应用启动初始化
 │    ├── error/
 │    │    └── app_error.dart           # 统一异常类型
 │    ├── mixins/
 │    │    └── background_operation_mixin.dart  # 后台操作生命周期管理
 │    ├── network/
 │    │    └── base_http_client.dart    # HTTP 客户端封装（dio + 日志拦截）
 │    ├── platform/
 │    │    ├── platform_capabilities.dart       # 平台能力检测
 │    │    ├── foreground_service_interface.dart # 前台服务接口
 │    │    ├── foreground_service_impl.dart      # 前台服务实现
 │    │    ├── system_tray_interface.dart        # 系统托盘接口
 │    │    └── system_tray_impl.dart             # 系统托盘实现
 │    ├── state/
 │    │    └── base_state.dart          # 泛型状态机（idle/loading/success/error）
 │    └── storage/
 │         └── image_storage.dart       # 图片文件缓存（LRU 淘汰）
 ├── exceptions/
 │    └── app_exception.dart            # 应用异常层次（Network/Api/Validation/Cancel/Cache）
 ├── models/
 │    ├── image_result.dart             # 图片结果模型
 │    ├── network_log.dart              # 网络日志模型
 │    ├── chat/
 │    │    └── chat_models.dart         # 对话相关模型
 │    ├── edit/
 │    │    ├── edit_request.dart        # 图编辑请求模型
 │    │    └── edit_response.dart       # 图编辑响应模型
 │    └── generate/
 │         ├── generate_request.dart    # 文生图请求模型
 │         └── generate_response.dart   # 文生图响应模型
 ├── providers/
 │    ├── settings_provider.dart        # 全局设置 + 服务层 providers
 │    ├── generate_provider.dart        # 文生图状态管理
 │    ├── edit_provider.dart            # 图编辑状态管理
 │    ├── chat_provider.dart            # 对话状态管理（含历史持久化）
 │    └── network_log_provider.dart     # 网络日志状态管理
 ├── services/
 │    ├── api_client.dart               # HTTP 客户端（dio 封装）
 │    ├── image_service.dart            # 图片 API 服务（generations / edits）
 │    └── chat_service.dart              # 对话 API 服务（chat completions）
 ├── repositories/
 │    └── image_repository.dart         # 图片数据转换 + 错误封装 + LRU 缓存
 ├── pages/
 │    ├── home_page.dart                # 主页（底部导航 + 页面切换 + AppBar）
 │    ├── generate/
 │    │    └── generate_page.dart       # 文生图页面
 │    ├── edit/
 │    │    └── edit_page.dart           # 图编辑页面
 │    ├── chat/
 │    │    └── chat_page.dart           # 对话页面
 │    ├── preview/
 │    │    └── image_preview_page.dart  # 大图预览页
 │    └── settings/
 │         └── settings_page.dart       # 设置页面
 └── widgets/
      ├── common/
      │    ├── confirm_dialog.dart      # 确认对话框
      │    ├── empty_state.dart         # 空状态组件
      │    ├── error_banner.dart         # 错误提示横幅
      │    ├── loading_indicator.dart   # 加载进度指示器
      │    └── result_grid.dart          # 图片结果网格
      └── network_log_dialog.dart       # 网络日志弹窗
```

## API 端点

| 功能 | 方法 | 地址 |
|------|------|------|
| 文生图 | POST | `/v1/images/generations` |
| 图编辑 | POST (multipart) | `/v1/images/edits` |
| AI 对话 | POST | `/v1/chat/completions` |

所有 API 请求需要在 Header 中携带 `Authorization: Bearer {{API_KEY}}`。

## 数据流

```
UI (Page) → Provider → Repository → Service → HTTP → API
                                                       ↓
UI ← Provider ← Repository ← Service ← HTTP ← API
       业务模型      数据转换     原始响应
```

各层职责：
- **UI (Page)**: 展示与交互
- **Provider**: 页面状态管理 + 通知服务
- **Repository**: 数据转换、错误封装、LRU 缓存、请求取消
- **Service**: HTTP 调用、基础解析
- **API**: 远端服务
