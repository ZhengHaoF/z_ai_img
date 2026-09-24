import 'package:flutter/foundation.dart';

typedef SystemTrayOpenWindowCallback = VoidCallback;
typedef SystemTrayCancelTaskCallback = VoidCallback;
typedef SystemTrayQuitCallback = VoidCallback;

abstract class ISystemTrayService {
  Future<void> initialize({
    SystemTrayOpenWindowCallback? onOpenWindow,
    SystemTrayCancelTaskCallback? onCancelTask,
    SystemTrayQuitCallback? onQuit,
  });
  Future<void> dispose();
  bool get isSupported;
}
