import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生 Android 前台服务的 Dart 桥接层。
/// 通过 MethodChannel 控制原生 Kotlin 的 GenerateForegroundService。
class NativeForegroundService {
  static const _channel = MethodChannel('com.zai.app/foreground');

  /// 启动前台保活服务
  static Future<bool> start({String title = 'AI 任务进行中', String body = '请稍候...'}) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'title': title,
        'body': body,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[NativeForegroundService] 启动失败: $e');
      return false;
    }
  }

  /// 停止前台保活服务
  static Future<bool> stop() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      return result ?? false;
    } catch (e) {
      debugPrint('[NativeForegroundService] 停止失败: $e');
      return false;
    }
  }
}
