import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'app.dart';
import 'providers/settings_provider.dart';
import 'utils/foreground_service.dart';
import 'utils/system_tray.dart';

void main() async {
  // ===== Flutter 全局错误回调 =====
  FlutterError.onError = (details) {
    debugPrint('🔥 [Flutter 同步异常] ${details.exception}');
    debugPrint('📜 ${details.stackFilter}');
  };

  // ===== Dart Zone 捕获所有异常 =====
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final sharedPreferences = await SharedPreferences.getInstance();

    // 初始化通知服务
    try {
      await ForegroundService.requestPermission();
    } catch (e) {
      debugPrint('⚠️ 初始化通知服务失败: $e');
    }

    // 根据设置初始化平台状态管理器（仅托盘）
    try {
      await _initializePlatformStatus(sharedPreferences);
    } catch (e) {
      debugPrint('⚠️ 初始化平台状态管理器失败: $e');
    }

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const App(),
      ),
    );
  }, (error, stackTrace) {
    // 捕获所有未处理的异常
    debugPrint('💥 [Zone 异常] $error');
    debugPrint('📜 $stackTrace');
  });
}

/// 根据平台初始化对应的状态管理器
Future<void> _initializePlatformStatus(SharedPreferences prefs) async {
  final showTrayIcon = prefs.getBool('showTrayIcon') ?? false;

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Windows/Mac/Linux: 根据设置初始化系统托盘
    if (showTrayIcon) {
      await SystemTrayManager.instance.initialize(
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