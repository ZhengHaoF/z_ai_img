import 'package:flutter/foundation.dart';
import '../../utils/foreground_service.dart';
import 'notification_service_interface.dart';

class NotificationServiceImpl implements INotificationService {
  @override
  bool get isSupported => !kIsWeb;

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return ForegroundService.requestPermission();
  }

  @override
  Future<void> showGeneratingNotification({String? title, String? body}) async {
    if (!isSupported) return;
    await ForegroundService.showGeneratingNotification(title: title, body: body);
  }

  @override
  Future<void> showCompletedNotification({required String title, required String body}) async {
    if (!isSupported) return;
    await ForegroundService.showCompletedNotification(title: title, body: body);
  }

  @override
  Future<void> cancelGenerating() async {
    if (!isSupported) return;
    await ForegroundService.cancelGenerating();
  }

  @override
  Future<void> updateGeneratingNotification({required String title, required String body}) async {
    if (!isSupported) return;
    await ForegroundService.updateGeneratingNotification(title: title, body: body);
  }
}
