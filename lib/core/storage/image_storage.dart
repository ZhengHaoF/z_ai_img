import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  final Directory directory;
  final int maxCacheSizeMB;

  ImageStorage(this.directory, {this.maxCacheSizeMB = 500});

  static Future<ImageStorage> create({int maxCacheSizeMB = 500}) async {
    final appDir = await getApplicationSupportDirectory();
    final imageDir = Directory('${appDir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return ImageStorage(imageDir, maxCacheSizeMB: maxCacheSizeMB);
  }

  Future<String> save(String id, Uint8List data) async {
    final file = File('${directory.path}/$id.png');
    await file.writeAsBytes(data);
    _scheduleEviction();
    return file.path;
  }

  Future<Uint8List?> load(String id) async {
    final file = File('${directory.path}/$id.png');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> clear() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      await directory.create(recursive: true);
    }
  }

  Future<int> get sizeInBytes async {
    if (!await directory.exists()) {
      return 0;
    }

    int total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
    return total;
  }

  void _scheduleEviction() {
    Future.microtask(() async {
      final sizeInBytes = await this.sizeInBytes;
      final maxBytes = maxCacheSizeMB * 1024 * 1024;
      if (sizeInBytes > maxBytes) {
        await _evictOldest();
      }
    });
  }

  Future<void> _evictOldest() async {
    if (!await directory.exists()) {
      return;
    }

    final files = directory.listSync().whereType<File>().toList();
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    for (final file in files) {
      try {
        await file.delete();
      } catch (_) {
        // ignore
      }
      final sizeInBytes = await this.sizeInBytes;
      if (sizeInBytes <= maxCacheSizeMB * 1024 * 1024) {
        break;
      }
    }
  }
}
