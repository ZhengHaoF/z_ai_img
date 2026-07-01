import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat/chat_models.dart';
import '../config/api_config.dart';
import 'settings_provider.dart';

const String _chatHistoryKey = 'chat_history';

/// 对话状态
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

  /// 清空错误
  ChatState clearError() {
    return ChatState(
      messages: messages,
      isLoading: isLoading,
      error: null,
    );
  }
}

/// 对话历史存储工具类
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

/// 对话 Notifier
class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  CancelToken? _cancelToken;
  String? _loadingMessageId; // 当前加载中的消息ID

  ChatNotifier(this._ref) : super(const ChatState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final messages = await ChatHistoryStorage.load();
    // 过滤掉加载中的消息（防止重启后残留）
    final validMessages = messages.where((m) => !m.isLoading).toList();
    if (validMessages.isNotEmpty) {
      state = state.copyWith(messages: validMessages);
    }
  }

  Future<void> _saveHistory() async {
    // 只保存非加载中的消息
    final validMessages = state.messages.where((m) => !m.isLoading).toList();
    await ChatHistoryStorage.save(validMessages);
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // 添加用户消息
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: content,
    );

    // 添加一个空的 AI 消息作为占位符（加载中状态）
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

    // 准备对话历史（不包含加载中的消息）
    final messagesForApi = state.messages
        .where((m) => !m.isLoading)
        .map((msg) => {'role': msg.role.value, 'content': msg.content})
        .toList();

    try {
      final chatService = _ref.read(chatServiceProvider);
      _cancelToken = CancelToken();

      final response = await chatService.sendMessage(
        model: ApiConfig.defaultChatModel,
        messages: messagesForApi,
        temperature: ApiConfig.defaultTemperature,
        cancelToken: _cancelToken,
      );

      // 用实际回复替换加载中的占位消息
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
      await _saveHistory();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // 取消时移除加载中的占位消息
        _removeLoadingMessage();
      } else {
        // 失败时移除加载中的占位消息，显示错误
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

  /// 取消当前请求
  void cancelRequest() {
    _cancelToken?.cancel('用户取消');
    _removeLoadingMessage();
  }

  /// 清空对话
  Future<void> clearChat() async {
    _cancelToken?.cancel('清空对话');
    state = const ChatState();
    await ChatHistoryStorage.clear();
  }

  /// 删除消息
  Future<void> deleteMessage(String id) async {
    state = state.copyWith(
      messages: state.messages.where((msg) => msg.id != id).toList(),
    );
    await _saveHistory();
  }

  /// 清空错误
  void clearError() {
    state = state.clearError();
  }
}

/// Chat provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});