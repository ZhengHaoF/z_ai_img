import 'dart:io';
import 'dart:typed_data';

class ImageStorage {
  final Directory directory;
  final int maxCacheSizeMB;

  ImageStorage(this.directory, {this.maxCacheSizeMB = 500});

  Future<String> save(String id, Uint8List data) async {
    // 目录可能尚未创建（首次写入 / 被系统清理），这里做兜底创建，
    // 否则 writeAsBytes 会因父目录不存在而抛错，缓存静默失效。
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

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
