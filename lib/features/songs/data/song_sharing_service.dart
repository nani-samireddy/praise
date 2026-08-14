import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../presentation/lyrics_document.dart';

abstract interface class SongSharingService {
  Future<void> copySong(Song song);

  Future<void> shareSong(Song song, {Rect? sharePositionOrigin});
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
    ..add(_formatLyricsForSharing(song.body));

  if (song.englishBody case final englishBody?) {
    output
      ..add('')
      ..add('English lyrics')
      ..add('')
      ..add(_formatLyricsForSharing(englishBody));
  }
  return output.join('\n').trim();
}

String _formatLyricsForSharing(String body) {
  return parseLyricsDocument(body)
      .map((block) {
        return switch (block.type) {
          LyricsBlockType.lyrics => block.text,
          LyricsBlockType.section => '[${block.text}]',
          LyricsBlockType.repeat => block.text,
        };
      })
      .join('\n\n');
}
