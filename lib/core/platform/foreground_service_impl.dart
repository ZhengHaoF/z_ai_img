import 'package:flutter/foundation.dart';
import './foreground_service_interface.dart';
import '../../utils/foreground_service.dart';

class ForegroundServiceImpl implements IForegroundService {
  @override
  bool get isSupported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return ForegroundService.requestPermission();
  }

  @override
  Future<void> start({required String title, String? body}) async {
    if (!isSupported) return;
    await ForegroundService.showGeneratingNotification(title: title, body: body);
  }

  @override
  Future<void> stop() async {
    if (!isSupported) return;
    await ForegroundService.cancelGenerating();
  }

  @override
  Future<void> update({String? title, String? body}) async {
    if (!isSupported) return;
    await ForegroundService.updateGeneratingNotification(title: title ?? '', body: body ?? '');
  }
}
