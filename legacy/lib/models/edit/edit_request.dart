import 'dart:convert';
import 'dart:typed_data';

class EditRequest {
  final List<Uint8List> images;
  final String prompt;
  final Uint8List? mask;
  final String? model;
  final int? n;
  final String? size;
  final String? quality;
  final String? background;
  final String? moderation;

  EditRequest({
    required this.images,
    required this.prompt,
    this.mask,
    this.model,
    this.n,
    this.size,
    this.quality,
    this.background,
    this.moderation,
  });

  /// OpenAI `/images/edits` multipart 字段。
  Map<String, dynamic> toFormData() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (n != null) 'n': n.toString(),
      if (size != null) 'size': size,
      if (quality != null) 'quality': quality,
      if (background != null) 'background': background,
      if (moderation != null) 'moderation': moderation,
    };
  }

  /// 兼容协议（千问等）：与文生图共用 `/images/generations` 的 JSON 体。
  /// 图片以 Base64 data URI 放入 `image`；mask 不受支持，忽略。
  Map<String, dynamic> toGenerationsJson() {
    final imageUris = images
        .map((bytes) => 'data:image/png;base64,${base64Encode(bytes)}')
        .toList();
    return {
      if (model != null) 'model': model,
      'prompt': prompt,
      if (n != null) 'n': n,
      if (size != null) 'size': size,
      'image': imageUris.length == 1 ? imageUris.first : imageUris,
    };
  }
}
