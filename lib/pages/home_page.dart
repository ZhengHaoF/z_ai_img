import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'generate/generate_page.dart';
import 'edit/edit_page.dart';
import 'settings/settings_page.dart';
import '../widgets/network_log_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    GeneratePage(),
    EditPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 玻璃背景色与导航栏前景色随明暗主题切换，避免深色模式下白底白字看不清。
    final glassColor =
        (isDark ? Colors.black : Colors.white).withValues(alpha: 0.72);
    final navForeground = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '文生图' : '图编辑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => _openLogDialog(),
            tooltip: '网络日志',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: ColoredBox(
              color: glassColor,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FadeIndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return TextStyle(
                          fontSize: 10,
                          color: navForeground.withValues(alpha: 0.55));
                    }
                    return TextStyle(
                        fontSize: 10,
                        color: navForeground.withValues(alpha: 0.35));
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                destinations: [
                  NavigationDestination(
                    icon: _AnimatedTabIcon(
                      isSelected: _currentIndex == 0,
                      child: const Icon(Icons.auto_awesome_outlined),
                    ),
                    selectedIcon: _AnimatedTabIcon(
                      isSelected: true,
                      child: const Icon(Icons.auto_awesome),
                    ),
                    label: '文生图',
                  ),
                  NavigationDestination(
                    icon: _AnimatedTabIcon(
                      isSelected: _currentIndex == 1,
                      child: const Icon(Icons.edit_outlined),
                    ),
                    selectedIcon: _AnimatedTabIcon(
                      isSelected: true,
                      child: const Icon(Icons.edit),
                    ),
                    label: '图编辑',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _openLogDialog() {
    showDialog(
      context: context,
      builder: (context) => const NetworkLogDialog(),
    );
  }
}

class _AnimatedTabIcon extends StatelessWidget {
  const _AnimatedTabIcon({
    required this.isSelected,
    required this.child,
  });

  final bool isSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.elasticOut,
      child: child,
    );
  }
}

/// 带淡入淡出过渡的 IndexedStack。
///
/// 保留 IndexedStack 的子页面状态（输入框内容、滚动位置等），
/// 并在切换 index 时对新的子页面做透明度过渡，替代 AnimatedSwitcher
/// 因 child 类型不变而无法触发动画的问题。
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _currentIndex = widget.index;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(
        index: _currentIndex,
        children: widget.children,
      ),
    );
  }
}
