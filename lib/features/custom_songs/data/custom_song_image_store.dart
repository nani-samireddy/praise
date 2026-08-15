import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

abstract interface class CustomSongImageStore {
  Future<String> save(String sourcePath);

  Future<void> delete(String storedPath);
}

class LocalCustomSongImageStore implements CustomSongImageStore {
  LocalCustomSongImageStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<String> save(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('The selected song photo no longer exists.');
    }

    final directory = await _imageDirectory();
    await directory.create(recursive: true);
    final extension = _supportedExtension(path.extension(sourcePath));
    final destination = File(
      path.join(directory.path, '${_uuid.v4()}$extension'),
    );
    await source.copy(destination.path);
    return destination.path;
  }

  @override
  Future<void> delete(String storedPath) async {
    final directory = await _imageDirectory();
    final file = File(storedPath);
    if (!path.isWithin(directory.path, file.path)) return;
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _imageDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'custom_song_images'));
  }

  static String _supportedExtension(String value) {
    final extension = value.toLowerCase();
    return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
  }
}
