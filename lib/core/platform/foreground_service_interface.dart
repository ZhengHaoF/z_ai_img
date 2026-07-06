abstract class IForegroundService {
  Future<void> start({required String title, String? body});
  Future<void> stop();
  Future<void> update({String? title, String? body});
  bool get isSupported;
}
