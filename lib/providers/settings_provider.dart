import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/storage/image_storage.dart';
import '../repositories/image_repository.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/image_service.dart';
import 'network_log_provider.dart';

// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// Image storage provider
final imageStorageProvider = Provider<ImageStorage>((ref) {
  return ImageStorage(Directory(''));
});

class SettingsState {
  final List<ApiProfile> apiProfiles;
  final String activeProfileId;
  final String defaultModel;
  final String defaultSize;
  final int defaultCount;
  final bool isDarkMode;

  // 托盘设置
  final bool showTrayIcon;

  SettingsState({
    List<ApiProfile>? apiProfiles,
    String? activeProfileId,
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.isDarkMode = false,
    this.showTrayIcon = false,
  })  : apiProfiles = apiProfiles ?? const [],
        activeProfileId = activeProfileId ?? ApiConfig.defaultProfile().id;

  SettingsState copyWith({
    List<ApiProfile>? apiProfiles,
    String? activeProfileId,
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    bool? isDarkMode,
    bool? showTrayIcon,
  }) {
    return SettingsState(
      apiProfiles: apiProfiles ?? this.apiProfiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showTrayIcon: showTrayIcon ?? this.showTrayIcon,
    );
  }

  ApiProfile? activeProfile() {
    if (apiProfiles.isEmpty) return null;
    try {
      return apiProfiles.firstWhere((profile) => profile.id == activeProfileId);
    } on StateError {
      return apiProfiles.isNotEmpty ? apiProfiles.first : null;
    }
  }

  bool get hasApiKey {
    final profile = activeProfile();
    return profile != null && profile.apiKey.isNotEmpty;
  }

  bool get isTraySupported => PlatformCapabilities.supportsSystemTray;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final profilesJson = _prefs.getString(ApiConfig.sharedProfilesKey);
    List<ApiProfile> profiles;
    String activeProfileId;

    if (profilesJson != null && profilesJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(profilesJson);
        profiles = jsonList
            .map((json) => ApiProfile.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        profiles = ApiConfig.legacyProfile(
          _prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl,
          _prefs.getString('apiKey') ?? '',
        );
      }
    } else {
      final legacyBaseUrl = _prefs.getString('baseUrl') ?? ApiConfig.defaultBaseUrl;
      final legacyApiKey = _prefs.getString('apiKey') ?? '';
      profiles = ApiConfig.legacyProfile(legacyBaseUrl, legacyApiKey);
    }

    if (profiles.isEmpty) {
      profiles = [ApiConfig.defaultProfile()];
    }

    activeProfileId = _prefs.getString(ApiConfig.sharedActiveProfileIdKey) ?? profiles.first.id;
    if (!profiles.any((profile) => profile.id == activeProfileId)) {
      activeProfileId = profiles.first.id;
    }

    state = SettingsState(
      apiProfiles: profiles,
      activeProfileId: activeProfileId,
      defaultModel: _prefs.getString('defaultModel') ?? 'gpt-image-2',
      defaultSize: _prefs.getString('defaultSize') ?? '1024x1024',
      defaultCount: _prefs.getInt('defaultCount') ?? 1,
      isDarkMode: _prefs.getBool('isDarkMode') ?? false,
      showTrayIcon: _prefs.getBool('showTrayIcon') ?? false,
    );
  }

  Future<void> _persistProfiles(List<ApiProfile> profiles, {String? activeProfileId}) async {
    final jsonList = profiles.map((profile) => profile.toJson()).toList();
    await _prefs.setString(ApiConfig.sharedProfilesKey, jsonEncode(jsonList));
    if (activeProfileId != null) {
      await _prefs.setString(ApiConfig.sharedActiveProfileIdKey, activeProfileId);
    }
  }

  ApiProfile _activeOrFirst() {
    final profile = state.activeProfile();
    if (profile != null) return profile;
    final first = state.apiProfiles.isNotEmpty ? state.apiProfiles.first : ApiConfig.defaultProfile();
    return first;
  }

  Future<void> setApiKey(String value) async {
    final profile = _activeOrFirst();
    final updated = profile.copyWith(apiKey: value);
    final profiles = _upsertProfile(state.apiProfiles, updated);
    final activeId = updated.id;
    await _persistProfiles(profiles, activeProfileId: activeId);
    state = state.copyWith(apiProfiles: profiles, activeProfileId: activeId);
  }

  Future<void> setBaseUrl(String value) async {
    final profile = _activeOrFirst();
    final updated = profile.copyWith(baseUrl: value);
    final profiles = _upsertProfile(state.apiProfiles, updated);
    final activeId = updated.id;
    await _persistProfiles(profiles, activeProfileId: activeId);
    state = state.copyWith(apiProfiles: profiles, activeProfileId: activeId);
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

  Future<void> setShowTrayIcon(bool value) async {
    await _prefs.setBool('showTrayIcon', value);
    state = state.copyWith(showTrayIcon: value);
  }

  Future<void> switchProfile(String profileId) async {
    if (!state.apiProfiles.any((profile) => profile.id == profileId)) return;
    await _prefs.setString(ApiConfig.sharedActiveProfileIdKey, profileId);
    state = state.copyWith(activeProfileId: profileId);
  }

  Future<String> addProfile(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('配置名称不能为空');

    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final profile = ApiProfile(
      id: 'profile_$now',
      name: trimmedName,
      apiKey: '',
      baseUrl: ApiConfig.defaultBaseUrl,
    );

    final profiles = List<ApiProfile>.from(state.apiProfiles)..add(profile);
    await _persistProfiles(profiles, activeProfileId: profile.id);
    state = state.copyWith(apiProfiles: profiles, activeProfileId: profile.id);
    return profile.id;
  }

  Future<void> updateProfile(ApiProfile profile) async {
    final trimmedName = profile.name.trim();
    if (trimmedName.isEmpty) return;

    final updated = profile.copyWith(name: trimmedName);
    final profiles = _upsertProfile(state.apiProfiles, updated);
    final activeId = state.activeProfileId;
    if (!profiles.any((profile) => profile.id == activeId)) {
      final fallbackId = profiles.isNotEmpty ? profiles.first.id : activeId;
      await _persistProfiles(profiles, activeProfileId: fallbackId);
      state = state.copyWith(apiProfiles: profiles, activeProfileId: fallbackId);
    } else {
      await _persistProfiles(profiles);
      state = state.copyWith(apiProfiles: profiles);
    }
  }

  Future<void> removeProfile(String profileId) async {
    if (state.apiProfiles.length <= 1) return;
    if (state.activeProfileId == profileId) {
      final fallback = state.apiProfiles.firstWhere((profile) => profile.id != profileId);
      final profiles = state.apiProfiles.where((profile) => profile.id != profileId).toList();
      await _persistProfiles(profiles, activeProfileId: fallback.id);
      state = state.copyWith(apiProfiles: profiles, activeProfileId: fallback.id);
    } else {
      final profiles = state.apiProfiles.where((profile) => profile.id != profileId).toList();
      await _persistProfiles(profiles);
      state = state.copyWith(apiProfiles: profiles);
    }
  }

  Future<void> clearAll() async {
    await _prefs.remove(ApiConfig.sharedProfilesKey);
    await _prefs.remove(ApiConfig.sharedActiveProfileIdKey);
    await _prefs.remove('baseUrl');
    await _prefs.remove('apiKey');
    state = SettingsState(
      apiProfiles: [ApiConfig.defaultProfile()],
      activeProfileId: ApiConfig.defaultProfile().id,
      defaultModel: 'gpt-image-2',
      defaultSize: '1024x1024',
      defaultCount: 1,
      isDarkMode: false,
      showTrayIcon: false,
    );
  }

  List<ApiProfile> _upsertProfile(List<ApiProfile> profiles, ApiProfile target) {
    final result = List<ApiProfile>.from(profiles);
    final index = result.indexWhere((profile) => profile.id == target.id);
    if (index >= 0) {
      result[index] = target;
    } else {
      result.add(target);
    }
    return result;
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

// API Client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();
  final client = ApiClient(
    baseUrl: profile.baseUrl,
    apiKey: profile.apiKey,
    onLog: (log) {
      ref.read(networkLogProvider.notifier).addLog(log);
    },
  );
  ref.listen<SettingsState>(settingsProvider, (prev, next) {
    final nextProfile = next.activeProfile();
    if (nextProfile == null) return;
    client.updateConfig(
      baseUrl: nextProfile.baseUrl,
      apiKey: nextProfile.apiKey,
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
  final storage = ref.watch(imageStorageProvider);
  return ImageRepository(imageService, apiClient, storage);
});

// Chat Service provider
final chatServiceProvider = Provider<ChatService>((ref) {
  final settings = ref.watch(settingsProvider);
  final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();
  final baseUrl = profile.resolveChatBaseUrl();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ),
  );
  final service = ChatService(
    dio: dio,
    baseUrl: baseUrl,
    apiKey: profile.apiKey,
    onLog: (log) {
      ref.read(networkLogProvider.notifier).addLog(log);
    },
  );
  ref.listen<SettingsState>(settingsProvider, (prev, next) {
    final nextProfile = next.activeProfile();
    if (nextProfile == null) return;
    service.updateApiKey(nextProfile.apiKey);
    service.updateBaseUrl(nextProfile.resolveChatBaseUrl());
  });
  return service;
});
