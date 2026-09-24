import 'dart:typed_data';

class ImageResult {
  final String id;
  final Uint8List imageData;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final String? prompt;

  ImageResult({
    required this.id,
    required this.imageData,
    this.width,
    this.height,
    DateTime? createdAt,
    this.prompt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get sizeLabel {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    return 'Unknown';
  }
}
