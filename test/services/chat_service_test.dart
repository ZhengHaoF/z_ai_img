import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_ai/exceptions/app_exception.dart';
import 'package:z_ai/services/chat_service.dart';

void main() {
  late Dio dio;
  late ChatService chatService;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    chatService = ChatService(
      dio: dio,
      baseUrl: 'https://example.com',
      apiKey: 'test-api-key',
    );
  });

  test('sendMessage 在 401 时应抛出 ApiException', () async {
    dio.options.validateStatus = (status) => status == 401;
    dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: (options, handler) async {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {'error': {'message': 'Unauthorized'}},
        ),
        type: DioExceptionType.badResponse,
      );
    }));

    final request = chatService.sendMessage(
      model: 'test-model',
      messages: const [{'role': 'user', 'content': 'test'}],
    );

    await expectLater(request, throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)));
  });

  test('sendMessage 在取消时应抛出 CancelException', () async {
    dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: (options, handler) async {
      throw DioException(requestOptions: options, type: DioExceptionType.cancel);
    }));

    final request = chatService.sendMessage(
      model: 'test-model',
      messages: const [{'role': 'user', 'content': 'test'}],
    );

    await expectLater(request, throwsA(isA<CancelException>()));
  });
}
