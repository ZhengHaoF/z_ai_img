import 'package:flutter/widgets.dart';

mixin BackgroundOperationMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _onBackground();
    } else if (state == AppLifecycleState.resumed) {
      _onForeground();
    }
  }

  void _onBackground() {
    if (isOperating) {
      updateGeneratingNotification(
        title: '⏸️ 处理仍在继续',
        body: '处理仍在继续，切回 App 查看结果',
      );
    }
  }

  void _onForeground() {
    final error = currentErrorMessage;
    if (error != null && _isBackgroundInterruptedError(error)) {
      showBackgroundInterruptedSnackBar();
    }
  }

  bool get isOperating;

  String? get currentErrorMessage;

  void updateGeneratingNotification({required String title, required String body});

  void showBackgroundInterruptedSnackBar();

  bool _isBackgroundInterruptedError(String error) {
    final normalized = error.toLowerCase();
    return normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('socket') ||
        normalized.contains('网络') ||
        normalized.contains('连接');
  }
}
