import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformCapabilities {
  static bool get isWeb => kIsWeb;

  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isLinux => Platform.isLinux;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  static bool get supportsNotifications => !kIsWeb;

  static bool get supportsSystemTray => !kIsWeb && isDesktop;

  static bool get supportsForegroundService =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get supportsNativeShare => !kIsWeb;

  static bool get supportsFilePicker => !kIsWeb;
}
