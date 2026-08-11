/// 判断错误文案是否可能由「切后台导致任务中断」引起。
///
/// generate / edit 页面在 [AppLifecycleState.resumed] 时共用同一套
/// 启发式嗅探逻辑，抽为纯函数避免两页重复实现。
bool isBackgroundInterruptedError(String error) {
  final normalized = error.toLowerCase();
  return normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('socket') ||
      normalized.contains('网络') ||
      normalized.contains('连接');
}
