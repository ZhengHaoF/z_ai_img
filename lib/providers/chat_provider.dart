import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/chat/chat_models.dart';
import '../services/chat_service.dart';
import 'settings_provider.dart';

const String _chatHistoryKey = 'chat_history';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  ChatState clearError() {
    return ChatState(
      messages: messages,
      isLoading: isLoading,
      error: null,
    );
  }
}

class ChatHistoryStorage {
  static Future<void> save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((msg) => msg.toJson()).toList();
    await prefs.setString(_chatHistoryKey, jsonEncode(jsonList));
  }

  static Future<List<ChatMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_chatHistoryKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;
  final dynamic _ref;
  CancelToken? _cancelToken;
  String? _loadingMessageId;
  Timer? _saveTimer;

  ChatNotifier(this._chatService, [dynamic ref])
      : _ref = ref ?? ProviderContainer(),
        super(const ChatState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final messages = await ChatHistoryStorage.load();
    final validMessages = messages.where((m) => !m.isLoading).toList();
    if (validMessages.isNotEmpty) {
      state = state.copyWith(messages: validMessages);
    }
  }

  Future<void> _saveHistory() async {
    final validMessages = state.messages.where((m) => !m.isLoading).toList();
    await ChatHistoryStorage.save(validMessages);
  }

  void _scheduleSaveHistory() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveHistory();
    });
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final settings = _ref.read(settingsProvider);
    final profile = settings.activeProfile() ?? ApiConfig.defaultProfile();
    final model = profile.defaultChatModel;
    final temperature = profile.defaultTemperature;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: content,
    );

    final loadingId = DateTime.now().millisecondsSinceEpoch.toString() + '_loading';
    final loadingMessage = ChatMessage(
      id: loadingId,
      role: ChatRole.assistant,
      content: '',
      isLoading: true,
    );
    _loadingMessageId = loadingId;

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isLoading: true,
      error: null,
    );

    final messagesForApi = state.messages
        .where((m) => !m.isLoading)
        .map((msg) => {'role': msg.role.value, 'content': msg.content})
        .toList();

    try {
      _cancelToken = CancelToken();

      final response = await _chatService.sendMessage(
        model: model,
        messages: messagesForApi,
        temperature: temperature,
        cancelToken: _cancelToken,
      );

      final updatedMessages = state.messages.map((msg) {
        if (msg.id == loadingId) {
          return ChatMessage(
            id: response.id,
            role: ChatRole.assistant,
            content: response.content,
            isLoading: false,
          );
        }
        return msg;
      }).toList();

      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
      );

      _loadingMessageId = null;
      _scheduleSaveHistory();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _removeLoadingMessage();
      } else {
        _removeLoadingMessage();
        state = state.copyWith(
          isLoading: false,
          error: e.message ?? '发送消息失败',
        );
      }
    } catch (e) {
      _removeLoadingMessage();
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _removeLoadingMessage() {
    if (_loadingMessageId == null) return;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != _loadingMessageId).toList(),
      isLoading: false,
    );
    _loadingMessageId = null;
  }

  void cancelRequest() {
    _cancelToken?.cancel('用户取消');
    _removeLoadingMessage();
  }

  Future<void> clearChat() async {
    _cancelToken?.cancel('清空对话');
    _saveTimer?.cancel();
    state = const ChatState();
    await ChatHistoryStorage.clear();
  }

  Future<void> deleteMessage(String id) async {
    state = state.copyWith(
      messages: state.messages.where((msg) => msg.id != id).toList(),
    );
    _scheduleSaveHistory();
  }

  void clearError() {
    state = state.clearError();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatNotifier(chatService, ref);
});
