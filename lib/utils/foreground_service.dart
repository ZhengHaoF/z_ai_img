import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/platform/platform_capabilities.dart';

/// 前台通知服务 - 用于后台保活和进度通知
class ForegroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int _currentNotificationId = 100;

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    if (!PlatformCapabilities.supportsNotifications) return false;

    try {
      await initialize();
      
      // 使用 permission_handler 请求 POST_NOTIFICATIONS 权限（Android 13+）
      final status = await Permission.notification.status;
      if (status.isGranted) {
        debugPrint('[ForegroundService] 通知权限已授予');
        return true;
      }
      final result = await Permission.notification.request();
      debugPrint('[ForegroundService] 通知权限请求结果: ${result.isGranted}');
      return result.isGranted;
    } catch (e) {
      debugPrint('[ForegroundService] 请求通知权限失败: $e');
      return false;
    }
  }

  /// 初始化
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    
    _initialized = true;
  }

  /// 确保通知渠道存在（每次显示通知前调用）
  static Future<void> _ensureChannel() async {
    const AndroidNotificationChannel generatingChannel = AndroidNotificationChannel(
      'generating_channel_v2',
      '图片生成进度',
      description: '显示图片生成进度',
      importance: Importance.high,
    );
    
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(generatingChannel);
    debugPrint('[ForegroundService] 通知渠道确保创建: generating_channel_v2');
  }

  /// 显示正在生成的通知（indeterminate 滚动进度条）
  static Future<void> showGeneratingNotification({
    String? title,
    String? body,
  }) async {
    if (!PlatformCapabilities.supportsNotifications) {
      debugPrint('[ForegroundService] showGeneratingNotification 跳过: 当前平台不支持通知');
      return;
    }

    try {
      debugPrint('[ForegroundService] showGeneratingNotification 被调用');
      await initialize();
      debugPrint('[ForegroundService] initialize 完成');
      await _ensureChannel();

      const androidDetails = AndroidNotificationDetails(
        'generating_channel_v2',
        '图片生成进度',
        channelDescription: '显示图片生成进度',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        progress: 0,
        maxProgress: 0,
      );

      const details = NotificationDetails(android: androidDetails);

      _currentNotificationId = 100;
      debugPrint('[ForegroundService] 准备显示通知: id=$_currentNotificationId, title=${title ?? '🎨 正在生成图片...'}, body=${body ?? '请稍候'}');
      await _notifications.show(
        _currentNotificationId,
        title ?? '🎨 正在生成图片...',
        body ?? '请稍候',
        details,
      );
      debugPrint('[ForegroundService] _notifications.show() 调用成功');
    } catch (e) {
      debugPrint('[ForegroundService] 显示生成通知失败: $e');
    }
  }

  /// 显示生成完成的通知
  static Future<void> showCompletedNotification({
    required String title,
    required String body,
  }) async {
    if (!PlatformCapabilities.supportsNotifications) return;

    try {
      await initialize();

      const androidDetails = AndroidNotificationDetails(
        'completed_channel',
        '生成完成',
        channelDescription: '图片生成完成通知',
      );

      const details = NotificationDetails(android: androidDetails);

      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      await _notifications.show(id, title, body, details);
    } catch (e) {
      // 静默失败
    }
  }

  /// 取消所有通知
  static Future<void> cancelAll() async {
    if (!PlatformCapabilities.supportsNotifications) return;
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // 静默失败
    }
  }

  /// 取消正在生成的通知
  static Future<void> cancelGenerating() async {
    if (!PlatformCapabilities.supportsNotifications) return;
    try {
      await _notifications.cancel(_currentNotificationId);
    } catch (e) {
      // 静默失败
    }
  }

  /// 更新正在生成的 notification（用于切后台时）
  static Future<void> updateGeneratingNotification({
    required String title,
    required String body,
  }) async {
    if (!PlatformCapabilities.supportsNotifications) return;
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        'generating_channel',
        '图片生成',
        channelDescription: '显示图片生成进度',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifications.show(_currentNotificationId, title, body, details);
    } catch (e) {
      debugPrint('更新生成通知失败: $e');
    }
  }
}