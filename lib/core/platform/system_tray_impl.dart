import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import './system_tray_interface.dart';
import '../../utils/system_tray.dart';

class SystemTrayServiceImpl implements ISystemTrayService {
  @override
  bool get isSupported => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Future<void> initialize({
    VoidCallback? onOpenWindow,
    VoidCallback? onCancelTask,
    VoidCallback? onQuit,
  }) async {
    if (!isSupported) return;
    await SystemTrayManager.instance.initialize(
      onOpenWindow: onOpenWindow,
      onCancelTask: onCancelTask,
      onQuit: onQuit,
    );
  }

  @override
  Future<void> dispose() async {
    if (!isSupported) return;
    await SystemTrayManager.instance.dispose();
  }
}
