import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'image_utils_nonweb.dart' if (dart.library.html) 'image_utils_web.dart';

class ImageUtils {
  static final ImagePicker _imagePicker = ImagePicker();

  // 从相册选择图片
  static Future<Uint8List?> pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
    );

    if (image != null) {
      return await image.readAsBytes();
    }
    return null;
  }

  // 从相机拍照
  static Future<Uint8List?> pickImageFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 4096,
      maxHeight: 4096,
    );

    if (image != null) {
      return await image.readAsBytes();
    }
    return null;
  }

  // 从文件选择器选择图片（桌面端）
  static Future<Uint8List?> pickImageFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      return result.files.single.bytes!;
    }
    return null;
  }

  // 选择多张图片
  static Future<List<Uint8List>> pickMultipleImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      maxWidth: 4096,
      maxHeight: 4096,
    );

    final results = <Uint8List>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      results.add(bytes);
    }
    return results;
  }

  // 保存图片（Web端下载，移动端保存到相册）
  static Future<bool> saveImage(Uint8List imageData, {String? fileName}) async {
    final name = fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.png';
    return await platformSaveImage(imageData, name);
  }
}
