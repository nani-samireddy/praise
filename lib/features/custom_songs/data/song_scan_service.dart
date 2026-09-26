import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scanned_song_draft.dart';

enum OnDeviceAiStatus { available, downloadable, downloading, unavailable }

abstract interface class SongScanService {
  Future<String> recognize(String imagePath);

  Future<OnDeviceAiStatus> getAiStatus();

  Future<void> downloadAiModel();

  Future<ScannedSongDraft> structure(String recognizedText);
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

  @override
  Future<OnDeviceAiStatus> getAiStatus() async {
    try {
      final value = await _channel.invokeMethod<String>('aiStatus');
      return OnDeviceAiStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => OnDeviceAiStatus.unavailable,
      );
    } on PlatformException {
      return OnDeviceAiStatus.unavailable;
    } on MissingPluginException {
      return OnDeviceAiStatus.unavailable;
    }
  }

  @override
  Future<void> downloadAiModel() async {
    await _channel.invokeMethod<void>('downloadAiModel');
  }

  @override
  Future<ScannedSongDraft> structure(String recognizedText) async {
    final songText = prepareOcrTextForSongAi(recognizedText);
    if (songText.isEmpty) {
      throw const FormatException('No likely song text was found in the scan.');
    }
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'structure',
      {'ocrText': songText},
    );
    if (value == null) {
      throw const FormatException('On-device AI returned no song.');
    }
    return createAiScannedSongDraft(value, recognizedText: songText);
  }
}

final songScanServiceProvider = Provider<SongScanService>((ref) {
  return const TesseractSongScanService();
});
