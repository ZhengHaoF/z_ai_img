import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// 系统托盘管理器 - Windows/Mac/Linux 平台专用
///
/// 需要准备以下图标文件（放在 assets/icons/ 目录下）：
/// - tray_idle.png    (灰色，空闲状态)
/// - tray_loading.png (蓝色，加载中状态)
/// - tray_completed.png (绿色，完成状态)
/// - tray_error.png   (红色，错误状态)
///
/// 图标尺寸建议：16x16 或 32x32 像素
class SystemTrayManager with TrayListener {
  SystemTrayManager._();

  static final SystemTrayManager instance = SystemTrayManager._();

  bool _isInitialized = false;
  VoidCallback? _onOpenWindow;
  VoidCallback? _onCancelTask;
  VoidCallback? _onQuit;

  /// 初始化托盘
  Future<void> initialize({
    VoidCallback? onOpenWindow,
    VoidCallback? onCancelTask,
    VoidCallback? onQuit,
  }) async {
    if (_isInitialized || !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }

    _onOpenWindow = onOpenWindow;
    _onCancelTask = onCancelTask;
    _onQuit = onQuit;

    try {
      // 设置托盘图标路径
      await trayManager.setIcon(_getTrayIconPath(TrayIconType.idle));

      // 设置 Tooltip
      await trayManager.setToolTip('AI 图片生成');

      // 设置右键菜单
      await _updateMenu(TrayIconType.idle);

      // 添加点击监听
      trayManager.addListener(this);

      _isInitialized = true;
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
    }
  }

  /// 获取托盘图标路径
  String _getTrayIconPath(TrayIconType type) {
    // 假设 assets 目录下有图标文件
    // 实际项目中需要添加图标资源
    switch (type) {
      case TrayIconType.idle:
        return 'assets/icons/tray_idle.png';
      case TrayIconType.loading:
        return 'assets/icons/tray_loading.png';
      case TrayIconType.completed:
        return 'assets/icons/tray_completed.png';
      case TrayIconType.error:
        return 'assets/icons/tray_error.png';
    }
  }

  /// 更新托盘菜单
  Future<void> _updateMenu(TrayIconType type) async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'open_window',
          label: '📂 打开主窗口',
        ),
        MenuItem.separator(),
        if (type == TrayIconType.loading)
          MenuItem(
            key: 'cancel_task',
            label: '🔄 取消生成',
          ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '❌ 退出',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  /// 设置托盘图标
  Future<void> setIcon(TrayIconType type) async {
    if (!_isInitialized) return;

    try {
      final iconPath = _getTrayIconPath(type);
      await trayManager.setIcon(iconPath);
      await _updateMenu(type);
    } catch (e) {
      debugPrint('设置托盘图标失败: $e');
    }
  }

  /// 设置 Tooltip
  Future<void> setTooltip(String tooltip) async {
    if (!_isInitialized) return;

    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      debugPrint('设置 Tooltip 失败: $e');
    }
  }

  /// 显示空闲状态
  Future<void> showIdle() async {
    await setIcon(TrayIconType.idle);
    await setTooltip('AI 图片生成 - 空闲');
  }

  /// 显示加载中状态
  Future<void> showLoading({String? message}) async {
    await setIcon(TrayIconType.loading);
    await setTooltip('AI 图片生成 - ${message ?? "处理中..."}');
  }

  /// 显示完成状态
  Future<void> showCompleted({String? message}) async {
    await setIcon(TrayIconType.completed);
    await setTooltip('AI 图片生成 - ${message ?? "完成！点击查看"}');

    // 3 秒后恢复空闲
    Future.delayed(const Duration(seconds: 3), () {
      if (_isInitialized) {
        showIdle();
      }
    });
  }

  /// 显示错误状态
  Future<void> showError({String? message}) async {
    await setIcon(TrayIconType.error);
    await setTooltip('AI 图片生成 - ${message ?? "生成失败"}');
  }

  /// 销毁托盘
  Future<void> dispose() async {
    if (!_isInitialized) return;

    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }

  // ============ TrayListener 实现 ============

  @override
  void onTrayIconMouseDown() {
    // 左键点击 - 打开窗口
    _onOpenWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    // 右键点击 - 显示菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open_window':
        _onOpenWindow?.call();
        break;
      case 'cancel_task':
        _onCancelTask?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }
}

/// 托盘图标类型
enum TrayIconType {
  idle,
  loading,
  completed,
  error,
}

/// 托盘状态便捷扩展
extension SystemTrayStatusExtension on SystemTrayManager {
  Future<void> showFromStatus({
    required TrayIconType status,
    String? message,
    double progress = 0,
  }) async {
    switch (status) {
      case TrayIconType.idle:
        await showIdle();
        break;
      case TrayIconType.loading:
        await showLoading(message: message ?? '生成中: ${(progress * 100).toInt()}%');
        break;
      case TrayIconType.completed:
        await showCompleted(message: message ?? '完成！');
        break;
      case TrayIconType.error:
        await showError(message: message ?? '生成失败');
        break;
    }
  }
}