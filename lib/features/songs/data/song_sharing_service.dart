import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import 'song_export_renderer.dart';
import 'song_share_formatter.dart';

abstract interface class SongSharingService {
  Future<void> copySong(Song song);

  Future<void> shareSong(Song song, {Rect? sharePositionOrigin});

  Future<void> shareSongImage(Song song, {Rect? sharePositionOrigin});

  Future<void> shareSongPdf(Song song, {Rect? sharePositionOrigin});
}

class PlatformSongSharingService implements SongSharingService {
  const PlatformSongSharingService();

  @override
  Future<void> copySong(Song song) {
    return Clipboard.setData(ClipboardData(text: buildSongShareText(song)));
  }

  @override
  Future<void> shareSong(Song song, {Rect? sharePositionOrigin}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: buildSongShareText(song),
        title: song.title,
        subject: song.title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  Future<void> shareSongImage(Song song, {Rect? sharePositionOrigin}) async {
    await _shareFile(
      song: song,
      bytes: await buildSongImageBytes(song),
      extension: 'png',
      mimeType: 'image/png',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  @override
  Future<void> shareSongPdf(Song song, {Rect? sharePositionOrigin}) async {
    await _shareFile(
      song: song,
      bytes: await buildSongPdfBytes(song),
      extension: 'pdf',
      mimeType: 'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _shareFile({
    required Song song,
    required Uint8List bytes,
    required String extension,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) async {
    final fileName = songExportFileName(song.title, extension);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        title: song.title,
        subject: song.title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

final songSharingServiceProvider = Provider<SongSharingService>((ref) {
  return const PlatformSongSharingService();
});

String buildSongShareText(Song song) {
  final output = <String>[song.title];
  if (song.englishTitle case final englishTitle?) {
    output.add(englishTitle);
  }
  if (song.author case final author?) {
    output.add('Author: $author');
  }

  output
    ..add('')
    ..add('Lyrics')
    ..add('')
    ..add(formatLyricsForSharing(song.body));

  if (song.englishBody case final englishBody?) {
    output
      ..add('')
      ..add('English lyrics')
      ..add('')
      ..add(formatLyricsForSharing(englishBody));
  }
  return output.join('\n').trim();
}
