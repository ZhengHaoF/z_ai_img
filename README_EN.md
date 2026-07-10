# Z Ai

**Z Ai** is a cross-platform AI image generation and editing app built with Flutter, with built-in AI chat capabilities. Supports iOS, Android, Web, macOS, Windows, and Linux.

## Core Features

| Feature | Description |
|---------|-------------|
| Text-to-Image | Generate images from text descriptions |
| Image Edit | Upload one or more images, describe edits, and let AI modify them |
| AI Chat | Chat with AI, with conversation history persistence |
| Fullscreen Preview | Tap generated/edited results to preview in fullscreen with zoom and save |
| Network Debug | Built-in network log panel for debugging API requests and responses |

## Tech Stack

- **Framework**: Flutter (SDK ^3.12.2)
- **Language**: Dart
- **State Management**: flutter_riverpod ^2.6.1
- **Networking**: dio ^5.8.0
- **Local Storage**: shared_preferences ^2.5.3
- **Image Handling**: image_picker ^1.1.2, file_picker ^8.1.7, gal ^2.3.0
- **Platform Notifications**: flutter_local_notifications ^18.0.0
- **Desktop Tray**: tray_manager ^0.2.3, window_manager ^0.4.3

## Supported Platforms

| Platform | Support |
|----------|---------|
| Android | Full support (including foreground service notifications) |
| iOS | Full support (including foreground service notifications) |
| Web | Supported (browser Notification API for notifications, download for saving images) |
| macOS | Supported (system tray) |
| Windows | Supported (system tray + window management) |
| Linux | Supported (system tray) |

## Getting Started

### Requirements

- Flutter SDK 3.12.2 or higher
- Dart SDK 3.12.2 or higher

### Install Dependencies

```bash
flutter pub get
```

### Configure API Key

On first run, configure your API Key. Tap the "Settings" icon in the top-right corner:
- **API Key**: Enter your API Key
- **Base URL**: Image generation/edit API address (default: `https://jeniya.cn`)
- **Chat Base URL**: AI chat API address (optional, auto-derived from Base URL if empty)

### Run the App

```bash
flutter run
```

### Build Release

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

## Project Structure

```
lib/
 ├── main.dart                          # App entry point
 ├── app.dart                           # MaterialApp + theme configuration
 ├── config/
 │    ├── api_config.dart               # API addresses, endpoints, default params, constants
 │    └── themes.dart                   # Theme configuration (Light/Dark)
 ├── core/
 │    ├── bootstrap.dart                # App startup initialization
 │    ├── error/
 │    │    └── app_error.dart           # Unified exception types
 │    ├── mixins/
 │    │    └── background_operation_mixin.dart  # Background operation lifecycle management
 │    ├── network/
 │    │    └── base_http_client.dart    # HTTP client wrapper (dio + logging interceptors)
 │    ├── platform/
 │    │    ├── platform_capabilities.dart       # Platform capability detection
 │    │    ├── foreground_service_interface.dart # Foreground service interface
 │    │    ├── foreground_service_impl.dart      # Foreground service implementation
 │    │    ├── system_tray_interface.dart        # System tray interface
 │    │    └── system_tray_impl.dart             # System tray implementation
 │    ├── state/
 │    │    └── base_state.dart          # Generic state machine (idle/loading/success/error)
 │    └── storage/
 │         └── image_storage.dart       # Image file cache (LRU eviction)
 ├── exceptions/
 │    └── app_exception.dart            # App exception hierarchy (Network/Api/Validation/Cancel/Cache)
 ├── models/
 │    ├── image_result.dart             # Image result model
 │    ├── network_log.dart              # Network request log model
 │    ├── chat/
 │    │    └── chat_models.dart         # Chat-related models
 │    ├── edit/
 │    │    ├── edit_request.dart        # Image edit request model
 │    │    └── edit_response.dart       # Image edit response model
 │    └── generate/
 │         ├── generate_request.dart    # Text-to-image request model
 │         └── generate_response.dart   # Text-to-image response model
 ├── providers/
 │    ├── settings_provider.dart        # Global settings + service layer providers
 │    ├── generate_provider.dart        # Text-to-image state management
 │    ├── edit_provider.dart            # Image edit state management
 │    ├── chat_provider.dart            # Chat state management (with history persistence)
 │    └── network_log_provider.dart     # Network log state management
 ├── services/
 │    ├── api_client.dart               # HTTP client (dio wrapper)
 │    ├── image_service.dart            # Image API service (generations / edits)
 │    └── chat_service.dart              # Chat API service (chat completions)
 ├── repositories/
 │    └── image_repository.dart         # Image data conversion + error wrapping + LRU cache
 ├── pages/
 │    ├── home_page.dart                # Home page (bottom navigation + page switching + AppBar)
 │    ├── generate/
 │    │    └── generate_page.dart       # Text-to-image page
 │    ├── edit/
 │    │    └── edit_page.dart           # Image edit page
 │    ├── chat/
 │    │    └── chat_page.dart           # Chat page (message list + input)
 │    ├── preview/
 │    │    └── image_preview_page.dart  # Fullscreen preview page (PageView + zoom + save)
 │    └── settings/
 │         └── settings_page.dart       # Settings page (API profiles / default params / theme / cache)
 └── widgets/
      ├── common/
      │    ├── confirm_dialog.dart      # Confirmation dialog
      │    ├── empty_state.dart         # Empty state widget
      │    ├── error_banner.dart         # Error banner
      │    ├── loading_indicator.dart   # Loading progress indicator
      │    └── result_grid.dart          # Image result grid
      └── network_log_dialog.dart       # Network log dialog (debug)
```

## API Endpoints

| Feature | Method | Endpoint |
|---------|--------|----------|
| Text-to-Image | POST | `/v1/images/generations` |
| Image Edit | POST (multipart) | `/v1/images/edits` |
| AI Chat | POST | `/v1/chat/completions` |

All API requests must include `Authorization: Bearer {{API_KEY}}` in the header.

## Data Flow

```
UI (Page) → Provider → Repository → Service → HTTP → API
                                                    ↓
UI ← Provider ← Repository ← Service ← HTTP ← API
       Business Model    Data Conversion    Raw Response
```

### Layer Responsibilities

| Layer | Responsibility | Data Format |
|-------|---------------|-------------|
| UI (Page) | Display and interaction | Widget / UI State |
| Provider | Page state management + notifications | Business model (e.g. `List<ImageResult>`) |
| Repository | Data conversion, error handling, caching, cancellation | Business model (`ImageResult`, `AppException`) |
| Service | HTTP calls, basic parsing | Raw request/response models |
| API | Remote service | JSON |
