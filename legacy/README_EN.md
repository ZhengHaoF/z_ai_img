# Z Ai

**Z Ai** is a cross-platform AI image generation and editing app built with Flutter. Supports Android and Windows.

## Core Features

| Feature | Description |
|---------|-------------|
| Text-to-Image | Generate images from text descriptions |
| Image Edit | Upload one or more images, describe edits, and let AI modify them |
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
- **Desktop Tray**: tray_manager ^0.2.3

## Supported Platforms

| Platform | Support |
|----------|---------|
| Android | Full support (including foreground service notifications) |
| Windows | Supported (system tray) |

> Web / iOS / macOS / Linux support has been dropped; there are no longer such build targets.

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

### Run the App

```bash
flutter run
```

### Build Release

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

## Project Structure

```
lib/
 ├── main.dart                              # App entry point
 ├── app.dart                               # MaterialApp + theme configuration
 ├── config/
 │    ├── api_config.dart                   # API addresses, endpoints, default params, constants
 │    └── themes.dart                       # Theme configuration (Light/Dark)
 ├── core/
 │    ├── bootstrap.dart                    # App startup initialization (resolves image cache dir)
 │    ├── network/
 │    │    └── base_http_client.dart        # HTTP client wrapper (dio + logging interceptors)
 │    ├── platform/
 │    │    ├── platform_capabilities.dart   # Platform capability detection
 │    │    ├── foreground_service_interface.dart  # Foreground service interface
 │    │    ├── foreground_service_impl.dart       # Foreground service implementation
 │    │    ├── system_tray_interface.dart   # System tray interface
 │    │    └── system_tray_impl.dart        # System tray implementation
 │    └── storage/
 │         └── image_storage.dart           # Image file cache (LRU eviction)
 ├── exceptions/
 │    └── app_exception.dart                # App exception hierarchy (Network/Api/Validation/Cancel/Cache)
 ├── models/
 │    ├── image_result.dart                 # Image result model
 │    ├── network_log.dart                  # Network request log model
 │    ├── edit/
 │    │    ├── edit_request.dart            # Image edit request model
 │    │    └── edit_response.dart           # Image edit response model
 │    └── generate/
 │         ├── generate_request.dart        # Text-to-image request model
 │         └── generate_response.dart       # Text-to-image response model
 ├── providers/
 │    ├── settings_provider.dart            # Global settings + service/repository providers
 │    ├── generate_provider.dart            # Text-to-image state management
 │    ├── edit_provider.dart                # Image edit state management
 │    └── network_log_provider.dart         # Network log state management
 ├── repositories/
 │    └── image_repository.dart             # Image data conversion + error wrapping + LRU cache
 ├── services/
 │    ├── api_client.dart                   # HTTP client (dio wrapper)
 │    └── image_service.dart                # Image API service (generations / edits)
 ├── pages/
 │    ├── home_page.dart                    # Home page (bottom navigation + page switching + AppBar)
 │    ├── generate/
 │    │    └── generate_page.dart           # Text-to-image page
 │    ├── edit/
 │    │    └── edit_page.dart               # Image edit page
 │    ├── preview/
 │    │    └── image_preview_page.dart      # Fullscreen preview page (PageView + zoom + save)
 │    └── settings/
 │         └── settings_page.dart           # Settings page (API profiles / default params / theme / cache)
 ├── widgets/
 │    ├── common/
 │    │    ├── confirm_dialog.dart          # Confirmation / single-line text input dialogs
 │    │    ├── empty_state.dart             # Empty state widget
 │    │    ├── error_banner.dart            # Error banner
 │    │    ├── feedback.dart                # SnackBar / copy / save feedback
 │    │    └── result_grid.dart             # Image result grid
 │    ├── params/
 │    │    ├── model_selector.dart          # Model selector
 │    │    ├── prompt_field.dart            # Prompt input field
 │    │    ├── result_section.dart          # Result section
 │    │    ├── size_count_selector.dart     # Size / count selector
 │    │    └── submit_button.dart           # Submit button
 │    ├── settings/
 │    │    ├── about_section.dart           # About
 │    │    ├── api_config_section.dart      # API profile management
 │    │    ├── appearance_section.dart      # Appearance (dark mode)
 │    │    ├── data_section.dart            # Data management (clear settings)
 │    │    └── tray_section.dart            # Tray icon toggle
 │    └── network_log_dialog.dart           # Network log dialog (debug)
 └── utils/
      ├── background_error.dart            # Background interruption error detection
      ├── foreground_service.dart          # Foreground notification service
      ├── image_utils.dart                 # Image pick / save utilities
      ├── native_foreground_service.dart   # Android foreground service bridge
      ├── system_tray.dart                 # System tray manager
      └── validators.dart                  # Form validation
```

## API Endpoints

| Feature | Method | Endpoint |
|---------|--------|----------|
| Text-to-Image | POST | `/v1/images/generations` |
| Image Edit | POST (multipart) | `/v1/images/edits` |

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
