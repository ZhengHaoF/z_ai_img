class GenerateRequest {
  final String model;
  final String prompt;
  final int n;
  final String size;

  /// OpenAI Images 扩展字段；兼容协议（千问等）不发送。
  final String? quality;
  final String? format;

  /// 图生图输入：公网 URL 或 `data:{MIME};base64,{data}`。
  /// 非空时走兼容协议的 I2I（与文生图共用 generations 端点）。
  final List<String>? images;

  GenerateRequest({
    required this.model,
    required this.prompt,
    required this.n,
    required this.size,
    this.quality,
    this.format,
    this.images,
  });

  Map<String, dynamic> toJson() {
    final imageList = images;
    return {
      'model': model,
      'prompt': prompt,
      'n': n,
      'size': size,
      if (quality != null) 'quality': quality,
      if (format != null) 'format': format,
      if (imageList != null && imageList.isNotEmpty)
        'image': imageList.length == 1 ? imageList.first : imageList,
    };
  }
}
