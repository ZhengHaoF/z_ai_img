import 'dart:io';

/// 平台能力检测。
///
/// 项目已明确放弃 Web 平台（仅支持 iOS / Android / Windows / macOS / Linux），
/// 因此这里不再需要 `!kIsWeb` 之类的前置判断，能力位只按「桌面 / 移动」区分。
class PlatformCapabilities {
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isLinux => Platform.isLinux;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  static bool get supportsSystemTray => isDesktop;

  static bool get supportsForegroundService =>
      Platform.isAndroid || Platform.isIOS;
}
