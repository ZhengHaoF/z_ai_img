import 'package:flutter/foundation.dart';

abstract class INotificationService {
  Future<bool> requestPermission();
  Future<void> showGeneratingNotification({String? title, String? body});
  Future<void> showCompletedNotification({required String title, required String body});
  Future<void> cancelGenerating();
  Future<void> updateGeneratingNotification({required String title, required String body});
  bool get isSupported;
}
