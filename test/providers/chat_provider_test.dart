import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z_ai/models/chat/chat_models.dart';
import 'package:z_ai/providers/chat_provider.dart';
import 'package:z_ai/services/chat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeChatService extends ChatService {
  _FakeChatService() : super(dio: Dio(BaseOptions(baseUrl: 'https://example.com')), baseUrl: 'https://example.com');

  @override
  Future<ChatResponse> sendMessage({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    CancelToken? cancelToken,
  }) async {
    return ChatResponse(
      id: 'response-1',
      object: 'chat.completion',
      created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: model,
      choices: [
        ChatChoice(
          message: ChatMessage(
            id: 'assistant-1',
            role: ChatRole.assistant,
            content: 'Hello!',
          ),
          finishReason: 'stop',
          index: 0,
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sendMessage 应在成功时添加消息', () async {
    final container = ProviderContainer();
    final chatNotifier = ChatNotifier(_FakeChatService(), container);
    await chatNotifier.sendMessage('Hi');

    expect(chatNotifier.state.messages.length, 2);
    expect(chatNotifier.state.messages[0].content, 'Hi');
    expect(chatNotifier.state.messages[1].content, 'Hello!');
    expect(chatNotifier.state.isLoading, false);
  });

  test('clearChat 应清空对话', () async {
    final container = ProviderContainer();
    final chatNotifier = ChatNotifier(_FakeChatService(), container);
    await chatNotifier.sendMessage('Hi');
    await chatNotifier.clearChat();

    expect(chatNotifier.state.messages.isEmpty, true);
    expect(chatNotifier.state.isLoading, false);
  });

  test('deleteMessage 应删除指定消息', () async {
    final container = ProviderContainer();
    final chatNotifier = ChatNotifier(_FakeChatService(), container);
    await chatNotifier.sendMessage('Hi');
    final messageId = chatNotifier.state.messages.first.id;
    await chatNotifier.deleteMessage(messageId);

    expect(chatNotifier.state.messages.length, 1);
    expect(chatNotifier.state.messages.any((m) => m.id == messageId), false);
  });

  test('clearError 应清空错误', () async {
    final container = ProviderContainer();
    final chatNotifier = ChatNotifier(_FakeChatService(), container);
    chatNotifier.state = chatNotifier.state.copyWith(error: 'error');
    chatNotifier.clearError();
    expect(chatNotifier.state.error, isNull);
  });
}
