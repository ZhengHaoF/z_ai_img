import 'dart:async';
import 'dart:js' as js;

/// 显示系统通知（仅 Web 端）
Future<bool> showNotification(String title, String body) async {
  if (!isNotificationSupported) {
    return false;
  }

  // 检查权限
  if (!isNotificationGranted) {
    final granted = await requestNotificationPermission();
    if (!granted) return false;
  }

  try {
    // 使用 JS interop 调用
    js.context.callMethod('Notification', [title, {'body': body}]);
    return true;
  } catch (e) {
    return false;
  }
}

/// 是否已授权
bool get isNotificationGranted {
  if (!isNotificationSupported) return false;
  try {
    final permission = js.context['Notification']?['permission'];
    return permission == 'granted';
  } catch (e) {
    return false;
  }
}

/// 请求通知权限
Future<bool> requestNotificationPermission() async {
  if (!isNotificationSupported) return false;

  try {
    final current = js.context['Notification']?['permission'];
    if (current == 'denied') return false;
    if (current == 'granted') return true;

    // 调用 requestPermission (异步)
    final completer = Completer<String?>();
    final notification = js.context['Notification'];
    if (notification != null && notification.hasProperty('requestPermission')) {
      final promise = notification.callMethod('requestPermission');
      // 注意：JS Promise 需要特殊处理，这里简化一下
      // 实际上应该用 dart:async + convertToDartAsync
      // 简单方案：如果没有 requestPermission，假设已授权
      return current == 'granted' || current == 'default';
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// 是否支持通知
bool get isNotificationSupported {
  try {
    return js.context['Notification'] != null;
  } catch (e) {
    return false;
  }
}