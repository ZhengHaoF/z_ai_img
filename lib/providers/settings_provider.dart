import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/image_service.dart';
import '../repositories/image_repository.dart';
import 'network_log_provider.dart';

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
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
    if (prev?.baseUrl != next.baseUrl || prev?.apiKey != next.apiKey) {
      client.updateConfig(baseUrl: next.baseUrl, apiKey: next.apiKey);
    }
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

// Settings state
class SettingsState {
  final String apiKey;
  final String baseUrl;
  final String defaultModel;
  final String defaultSize;
  final int defaultCount;
  final bool isDarkMode;

  const SettingsState({
    this.apiKey = '',
    this.baseUrl = ApiConfig.defaultBaseUrl,
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.isDarkMode = false,
  });

  SettingsState copyWith({
    String? apiKey,
    String? baseUrl,
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    bool? isDarkMode,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  bool get hasApiKey => apiKey.isNotEmpty;
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
