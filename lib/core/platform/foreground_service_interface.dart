/// 前台服务 / 通知能力的统一抽象。
///
/// 原先存在 `INotificationService` 与本接口两套几乎完全重复的抽象，
/// 且二者都只是委托同一个 `ForegroundService` 静态类，
/// 因此已合并为本接口，`INotificationService` 及其实现已删除。
abstract class IForegroundService {
  /// 当前平台是否支持前台服务 / 通知。
  bool get isSupported;

  /// 申请通知权限，返回是否已获授权。
  Future<bool> requestPermission();

  /// 开始展示「生成中」的前台通知。
  Future<void> start({required String title, String? body});

  /// 取消「生成中」的前台通知。
  Future<void> stop();

  /// 更新「生成中」的前台通知内容。
  Future<void> update({String? title, String? body});

  /// 展示「已完成」通知。
  Future<void> showCompleted({required String title, required String body});
}
