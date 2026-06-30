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
}
