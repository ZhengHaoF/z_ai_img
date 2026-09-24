import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z_ai/app.dart';
import 'package:z_ai/core/bootstrap.dart';
import 'package:z_ai/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppBootstrap.run 应完成基础初始化并启动 App', (tester) async {
    await tester.runAsync(() async {
      await AppBootstrap.run();
    });

    final context = tester.element(find.byType(App));
    final container = ProviderScope.containerOf(context, listen: false);
    final prefs = container.read(sharedPreferencesProvider);

    expect(prefs, isA<SharedPreferences>());
  });

  testWidgets('App 应根据设置切换主题模式', (tester) async {
    SharedPreferences.setMockInitialValues({'isDarkMode': true});

    await tester.runAsync(() async {
      await AppBootstrap.run();
    });

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
