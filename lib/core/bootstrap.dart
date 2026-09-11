import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../core/platform/foreground_service_interface.dart';
import '../core/platform/foreground_service_impl.dart';
import '../core/platform/system_tray_interface.dart';
import '../core/platform/system_tray_impl.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/storage/image_storage.dart';
import '../app.dart';

class AppBootstrap {
  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      debugPrint('🔥 [Flutter 同步异常] ${details.exception}');
      debugPrint('📜 ${details.stack}');
    };

    await runZonedGuarded(() async {
      final prefs = await SharedPreferences.getInstance();

      try {
        const IForegroundService foregroundService = ForegroundServiceImpl();
        if (foregroundService.isSupported) {
          await foregroundService.requestPermission();
        }
      } catch (e) {
        debugPrint('⚠️ 初始化通知服务失败: $e');
      }

      try {
        await _initializePlatformStatus(prefs);
      } catch (e) {
        debugPrint('⚠️ 初始化平台状态管理器失败: $e');
      }

      final imageCacheDir = await _resolveImageCacheDirectory();

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            imageStorageProvider.overrideWithValue(ImageStorage(imageCacheDir)),
          ],
          child: const App(),
        ),
      );
    }, (error, stackTrace) {
      debugPrint('💥 [Zone 异常] $error');
      debugPrint('📜 $stackTrace');
    });
  }

  /// 解析磁盘图片缓存的存储目录：应用私有支持目录下的 `image_cache`。
  ///
  /// 用 [getApplicationSupportDirectory] 而非临时目录，保证缓存可跨启动复用、
  /// 且不会被系统当作临时文件清理。测试等无 path_provider 插件的环境回退到系统临时目录。
  static Future<Directory> _resolveImageCacheDirectory() async {
    Directory dir;
    try {
      final supportDir = await getApplicationSupportDirectory();
      dir = Directory('${supportDir.path}${Platform.pathSeparator}image_cache');
    } catch (e) {
      debugPrint('⚠️ 获取应用支持目录失败，回退到系统临时目录: $e');
      dir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}z_ai_image_cache',
      );
    }

    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ 创建图片缓存目录失败: $e');
    }

    return dir;
  }

  static Future<void> _initializePlatformStatus(SharedPreferences prefs) async {
    final showTrayIcon = prefs.getBool('showTrayIcon') ?? false;

    if (PlatformCapabilities.isDesktop) {
      if (showTrayIcon) {
        final ISystemTrayService trayService = SystemTrayServiceImpl();
        if (trayService.isSupported) {
          await trayService.initialize(
            onOpenWindow: () {
              debugPrint('托盘: 打开主窗口');
            },
            onCancelTask: () {
              debugPrint('托盘: 取消任务');
            },
            onQuit: () {
              debugPrint('托盘: 退出应用');
              exit(0);
            },
          );
        }
      }
    }
  }
}
