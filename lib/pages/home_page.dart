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
    return Scaffold(
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
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '文生图',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: '图编辑',
          ),
        ],
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
