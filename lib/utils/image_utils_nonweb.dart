import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> platformSaveImage(Uint8List imageData, String fileName) async {
  if (kIsWeb) {
    return false;
  }

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