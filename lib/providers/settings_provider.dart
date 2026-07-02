import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/image_service.dart';
import '../repositories/image_repository.dart';
import '../services/chat_service.dart';
import 'chat_provider.dart';
import 'network_log_provider.dart';

// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// API Client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final client = ApiClient(
    baseUrl: prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl,
    apiKey: prefs.getString('apiKey') ?? '',
    onLog: (log) {
      ref.read(networkLogProvider.notifier).addLog(log);
    },
  );
  // 监听 settings 变化，实时更新 ApiClient 配置
  ref.listen<SettingsState>(settingsProvider, (prev, next) {
    client.updateConfig(
      baseUrl: next.baseUrl,
      apiKey: next.apiKey,
    );
  });
  return client;
});

// Image Service provider
final imageServiceProvider = Provider<ImageService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ImageService(apiClient);
});

// Image Repository provider
final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  final imageService = ref.watch(imageServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ImageRepository(imageService, apiClient);
});

// Chat Service provider
final chatServiceProvider = Provider<ChatService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final baseUrl = (prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl).replaceAll('/v1/images', '') + '/v1/chat';
  return ChatService(
    dio: Dio(BaseOptions(baseUrl: baseUrl)),
    onLog: (log) {
      ref.read(networkLogProvider.notifier).addLog(log);
    },
  );
});

class SettingsState {
  final String apiKey;
  final String baseUrl;
  final String defaultModel;
  final String defaultSize;
  final int defaultCount;
  final bool isDarkMode;

  // 托盘设置
  final bool showTrayIcon; // Windows/macOS/Linux: 是否显示托盘图标

  const SettingsState({
    this.apiKey = '',
    this.baseUrl = ApiConfig.defaultBaseUrl,
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.isDarkMode = false,
    this.showTrayIcon = false,
  });

  SettingsState copyWith({
    String? apiKey,
    String? baseUrl,
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    bool? isDarkMode,
    bool? showTrayIcon,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showTrayIcon: showTrayIcon ?? this.showTrayIcon,
    );
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  // 是否支持托盘 (Windows/macOS/Linux 且非 Web)
  bool get isTraySupported => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}

// Settings notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SettingsState(
      apiKey: _prefs.getString('apiKey') ?? '',
      baseUrl: _prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl,
      defaultModel: _prefs.getString('defaultModel') ?? 'gpt-image-2',
      defaultSize: _prefs.getString('defaultSize') ?? '1024x1024',
      defaultCount: _prefs.getInt('defaultCount') ?? 1,
      isDarkMode: _prefs.getBool('isDarkMode') ?? false,
      showTrayIcon: _prefs.getBool('showTrayIcon') ?? false,
    );
  }

  Future<void> setApiKey(String value) async {
    await _prefs.setString('apiKey', value);
    state = state.copyWith(apiKey: value);
  }

  Future<void> setBaseUrl(String value) async {
    await _prefs.setString('baseUrl', value);
    state = state.copyWith(baseUrl: value);
  }

  Future<void> setDefaultModel(String value) async {
    await _prefs.setString('defaultModel', value);
    state = state.copyWith(defaultModel: value);
  }

  Future<void> setDefaultSize(String value) async {
    await _prefs.setString('defaultSize', value);
    state = state.copyWith(defaultSize: value);
  }

  Future<void> setDefaultCount(int value) async {
    await _prefs.setInt('defaultCount', value);
    state = state.copyWith(defaultCount: value);
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
    state = state.copyWith(isDarkMode: value);
  }

  // 设置是否显示托盘图标 (Windows/macOS/Linux)
  Future<void> setShowTrayIcon(bool value) async {
    await _prefs.setBool('showTrayIcon', value);
    state = state.copyWith(showTrayIcon: value);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    state = const SettingsState();
  }
}

// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});