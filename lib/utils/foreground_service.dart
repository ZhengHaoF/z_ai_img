import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 前台通知服务 - 用于后台保活和进度通知
class ForegroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int _currentNotificationId = 100;

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    try {
      await initialize();
      return true;
    } catch (e) {
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

  /// 显示正在生成的通知
  static Future<void> showGeneratingNotification({
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return;

    try {
      await initialize();

      const androidDetails = AndroidNotificationDetails(
        'generating_channel',  // 必须与 AndroidManifest.xml 中的渠道 ID 一致
        '图片生成',
        channelDescription: '显示图片生成进度',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,  // 正在进行的通知，用户不能滑动删除
        autoCancel: false,
      );

      const details = NotificationDetails(android: androidDetails);

      _currentNotificationId = 100;
      await _notifications.show(
        _currentNotificationId,
        title ?? '🎨 正在生成图片...',
        body ?? '请稍候',
        details,
      );
    } catch (e) {
      debugPrint('显示生成通知失败: $e');
    }
  }

  /// 显示生成完成的通知
  static Future<void> showCompletedNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

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
    if (kIsWeb) return;
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // 静默失败
    }
  }

  /// 取消正在生成的通知
  static Future<void> cancelGenerating() async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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