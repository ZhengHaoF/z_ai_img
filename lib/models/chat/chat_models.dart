/// 对话消息角色
enum ChatRole {
  user,
  assistant,
  system;

  String get value {
    switch (this) {
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
      case ChatRole.system:
        return 'system';
    }
  }

  static ChatRole fromString(String value) {
    switch (value) {
      case 'user':
        return ChatRole.user;
      case 'assistant':
        return ChatRole.assistant;
      case 'system':
        return ChatRole.system;
      default:
        return ChatRole.user;
    }
  }
}

/// 对话消息
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading; // 是否正在加载中

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 从 JSON 创建
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.fromString(json['role'] ?? 'user'),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isLoading: json['isLoading'] ?? false,
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.value,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
    };
  }

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 对话请求
class ChatRequest {
  final String model;
  final List<Map<String, String>> messages;
  final double temperature;
  final int? maxTokens;

  ChatRequest({
    required this.model,
    required this.messages,
    this.temperature = 0.7,
    this.maxTokens,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
    };
    if (maxTokens != null) {
      json['max_tokens'] = maxTokens;
    }
    return json;
  }
}

/// 对话响应
class ChatResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final Map<String, int>? usage;
  final List<ChatChoice> choices;

  ChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    this.usage,
    required this.choices,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    // 安全解析 created 字段
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // 安全解析 usage 字段
    Map<String, int>? parseUsage(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, int>) return value;
      if (value is Map) {
        return Map<String, int>.from(value.map((k, v) =>
          MapEntry(k.toString(), parseInt(v))));
      }
      return null;
    }

    final choices = (json['choices'] as List<dynamic>?)
            ?.map((e) => ChatChoice.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ChatResponse(
      id: json['id'] ?? '',
      object: json['object'] ?? 'chat.completion',
      created: parseInt(json['created']),
      model: json['model'] ?? '',
      usage: parseUsage(json['usage']),
      choices: choices,
    );
  }

  /// 获取 AI 回复内容
  String get content {
    if (choices.isEmpty) return '';
    final message = choices.first.message;
    return message?.content ?? '';
  }

  /// 是否完成了回复
  bool get isFinished {
    if (choices.isEmpty) return false;
    return choices.first.finishReason == 'stop';
  }
}

/// 对话选择
class ChatChoice {
  final ChatMessage? message;
  final String finishReason;
  final int index;

  ChatChoice({
    this.message,
    required this.finishReason,
    required this.index,
  });

  factory ChatChoice.fromJson(Map<String, dynamic> json) {
    // 安全解析 index，避免类型转换错误
    int parseIndex(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return ChatChoice(
      message: json['message'] != null
          ? ChatMessage.fromJson(json['message'] as Map<String, dynamic>)
          : null,
      finishReason: json['finish_reason'] ?? '',
      index: parseIndex(json['index']),
    );
  }
}