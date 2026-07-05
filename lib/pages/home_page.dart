import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'generate/generate_page.dart';
import 'edit/edit_page.dart';
import 'chat/chat_page.dart';
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
    ChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '文生图' : _currentIndex == 1 ? '图编辑' : '对话'),
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
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex),
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return TextStyle(fontSize: 10, color: Colors.black.withValues(alpha: 0.55));
                    }
                    return TextStyle(fontSize: 10, color: Colors.black.withValues(alpha: 0.35));
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
                  NavigationDestination(
                    icon: _AnimatedTabIcon(
                      isSelected: _currentIndex == 2,
                      child: const Icon(Icons.chat_outlined),
                    ),
                    selectedIcon: _AnimatedTabIcon(
                      isSelected: true,
                      child: const Icon(Icons.chat),
                    ),
                    label: '对话',
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
