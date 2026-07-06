import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../core/platform/foreground_service_interface.dart';
import '../core/platform/foreground_service_impl.dart';
import '../core/platform/system_tray_interface.dart';
import '../core/platform/system_tray_impl.dart';
import '../core/platform/platform_capabilities.dart';
import '../utils/foreground_service.dart';
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
        final notificationService = ForegroundServiceImpl();
        if (notificationService.isSupported) {
          await ForegroundService.requestPermission();
        }
      } catch (e) {
        debugPrint('⚠️ 初始化通知服务失败: $e');
      }

      try {
        await _initializePlatformStatus(prefs);
      } catch (e) {
        debugPrint('⚠️ 初始化平台状态管理器失败: $e');
      }

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const App(),
        ),
      );
    }, (error, stackTrace) {
      debugPrint('💥 [Zone 异常] $error');
      debugPrint('📜 $stackTrace');
    });
  }

  static Future<void> _initializePlatformStatus(SharedPreferences prefs) async {
    final showTrayIcon = prefs.getBool('showTrayIcon') ?? false;

    if (PlatformCapabilities.isDesktop) {
      if (showTrayIcon) {
        final trayService = SystemTrayServiceImpl();
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
