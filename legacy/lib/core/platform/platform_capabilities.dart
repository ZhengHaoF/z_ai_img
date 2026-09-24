import 'dart:io';

/// 平台能力检测。
///
/// 项目当前仅支持 Android / Windows 两个平台（iOS / macOS / Linux 已放弃），
/// 因此这里不需要 `!kIsWeb` 之类的前置判断，能力位只按「桌面 / 移动」区分。
class PlatformCapabilities {
  static bool get isDesktop => Platform.isWindows;

  static bool get isMobile => Platform.isAndroid;

  static bool get isWindows => Platform.isWindows;

  static bool get isAndroid => Platform.isAndroid;

  static bool get supportsSystemTray => isDesktop;

  static bool get supportsForegroundService => Platform.isAndroid;
}
