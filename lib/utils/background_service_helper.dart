import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 前台服务 - 用于在 App 切后台时保持请求运行
@pragma('vm:entry-point')
class BackgroundServiceHelper {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// 初始化后台服务
  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // 不自动启动，需要时手动启动
        isForegroundMode: true,
        notificationChannelId: 'background_task',
        initialNotificationTitle: 'AI 图片生成',
        initialNotificationContent: '正在处理请求...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// iOS 背景回调
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// 服务主入口 - 必须添加 @pragma('vm:entry-point') 注解，否则 Release 模式会崩溃
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 模拟后台任务 - 保持存活
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // 更新通知内容表明还在运行
          service.setForegroundNotificationInfo(
            title: 'AI 图片生成',
            content: '正在处理请求...',
          );
        }
      }
      service.invoke('update');
    });
  }

  /// 启动前台服务
  static Future<bool> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      return await _service.startService();
    }
    return true;
  }

  /// 停止前台服务
  static Future<bool> stopService() async {
    _service.invoke('stopService');
    return true;
  }

  /// 判断服务是否在运行
  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}
