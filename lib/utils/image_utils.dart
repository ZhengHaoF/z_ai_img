import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 图片选择 / 保存工具（仅 iOS / Android / Windows / macOS / Linux）。
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

  // 保存图片（移动端写入系统相册）
  static Future<bool> saveImage(Uint8List imageData, {String? fileName}) async {
    final name = fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.png';
    return _saveImageToGallery(imageData, name);
  }

  /// 移动端：申请相册权限 → 写临时文件 → 存入相册 → 删除临时文件。
  /// 桌面端当前不支持保存，返回 false（调用方会给出失败提示）。
  static Future<bool> _saveImageToGallery(
    Uint8List imageData,
    String fileName,
  ) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        PermissionStatus? status;
        if (Platform.isAndroid) {
          status = await Permission.photos.request();
          if (status.isDenied || status.isPermanentlyDenied) {
            status = await Permission.storage.request();
          }
        } else if (Platform.isIOS) {
          status = await Permission.photos.request();
        }

        if (status != null && !status.isGranted) {
          debugPrint('相册权限未授予');
          return false;
        }

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(imageData);

        await Gal.putImage(filePath, album: 'AI图片');

        await file.delete();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Save image error: $e');
      return false;
    }
  }
}
