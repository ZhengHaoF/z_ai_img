class GenerateResponse {
  final List<ImageData> data;
  final String? error;

  GenerateResponse({
    required this.data,
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;

  factory GenerateResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return GenerateResponse(
      data: dataList.map((e) => ImageData.fromJson(e as Map<String, dynamic>)).toList(),
      error: json['error']?['message'] as String?,
    );
  }

  // 兼容从 choices 中提取的格式
  factory GenerateResponse.fromChoices(Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>? ?? [];
    final data = <ImageData>[];

    for (final choice in choices) {
      final message = choice['message'] as Map<String, dynamic>?;
      if (message != null) {
        final content = message['content'] as String?;
        if (content != null) {
          // content 可能是 base64 编码的图片
          data.add(ImageData(b64Json: content));
        }
      }
    }

    return GenerateResponse(
      data: data,
      error: json['error']?['message'] as String?,
    );
  }
}

class ImageData {
  final String? b64Json;
  final String? url;
  final String? revisedPrompt;

  ImageData({
    this.b64Json,
    this.url,
    this.revisedPrompt,
  });

  bool get hasB64Json => b64Json != null && b64Json!.isNotEmpty;

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      b64Json: json['b64_json'] as String?,
      url: json['url'] as String?,
      revisedPrompt: json['revised_prompt'] as String?,
    );
  }
}
