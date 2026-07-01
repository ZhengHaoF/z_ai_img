// 非 Web 端的空实现
Future<bool> showNotification(String title, String body) async {
  return false;
}

bool get isNotificationGranted => false;

Future<bool> requestNotificationPermission() async {
  return false;
}

bool get isNotificationSupported => false;