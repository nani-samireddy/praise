import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class SongScanService {
  Future<String> recognize(String imagePath);
}

class TesseractSongScanService implements SongScanService {
  const TesseractSongScanService();

  static const _channel = MethodChannel('com.nanisamireddy.praise/song_scan');

  @override
  Future<String> recognize(String imagePath) async {
    final text = await _channel.invokeMethod<String>('recognize', {
      'imagePath': imagePath,
    });
    return text ?? '';
  }
}

final songScanServiceProvider = Provider<SongScanService>((ref) {
  return const TesseractSongScanService();
});
