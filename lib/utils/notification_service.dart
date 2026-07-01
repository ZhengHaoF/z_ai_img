// 通知服务 - 根据平台自动选择实现
export 'notification_service_nonweb.dart' if (dart.library.html) 'notification_service_web.dart';