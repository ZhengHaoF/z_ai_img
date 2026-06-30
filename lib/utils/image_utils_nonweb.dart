import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

Future<bool> platformSaveImage(Uint8List imageData, String fileName) async {
  if (kIsWeb) {
    return false;
  }

  PermissionStatus status;

  if (Platform.isAndroid) {
    status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }
  } else if (Platform.isIOS) {
    status = await Permission.photos.request();
  } else {
    return false;
  }

  if (!status.isGranted && !status.isLimited) {
    final result = await PhotoManager.requestPermissionExtend();
    if (!result.isAuth) {
      return false;
    }
  }

  try {
    final result = await ImageGallerySaver.saveImage(
      imageData,
      quality: 100,
      name: fileName,
    );

    if (result != null && result['isSuccess'] == true) {
      return true;
    }
  } catch (e) {
    debugPrint('Save to gallery error: $e');
  }

  return false;
}
