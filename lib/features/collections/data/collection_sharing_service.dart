import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import 'collection_export_renderer.dart';
import 'collection_link_codec.dart';

abstract interface class CollectionSharingService {
  Future<void> copyCollection(SongCollection collection, List<Song> songs);

  Future<void> shareCollection(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  });

  Future<void> shareCollectionLink(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  });

  Future<void> shareCollectionImage(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  });

  Future<void> shareCollectionPdf(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  });
}

class PlatformCollectionSharingService implements CollectionSharingService {
  const PlatformCollectionSharingService();

  @override
  Future<void> copyCollection(SongCollection collection, List<Song> songs) {
    return Clipboard.setData(
      ClipboardData(text: buildCollectionShareText(collection, songs)),
    );
  }

  @override
  Future<void> shareCollection(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: buildCollectionShareText(collection, songs),
        title: collection.name,
        subject: collection.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  Future<void> shareCollectionLink(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  }) async {
    final link = buildCollectionLink(collection, songs);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Open this Praise list to add it to your app:\n$link',
        title: collection.name,
        subject: collection.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  Future<void> shareCollectionImage(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await buildCollectionImageBytes(
      collection,
      songs,
      includeSongs: includeSongs,
    );
    await _shareFile(
      collection: collection,
      bytes: bytes,
      extension: 'png',
      mimeType: 'image/png',
      includeSongs: includeSongs,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  @override
  Future<void> shareCollectionPdf(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await buildCollectionPdfBytes(
      collection,
      songs,
      includeSongs: includeSongs,
    );
    await _shareFile(
      collection: collection,
      bytes: bytes,
      extension: 'pdf',
      mimeType: 'application/pdf',
      includeSongs: includeSongs,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _shareFile({
    required SongCollection collection,
    required Uint8List bytes,
    required String extension,
    required String mimeType,
    required bool includeSongs,
    Rect? sharePositionOrigin,
  }) async {
    final fileName = collectionExportFileName(
      collection.name,
      extension,
      includeSongs: includeSongs,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        title: collection.name,
        subject: collection.name,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

final collectionSharingServiceProvider = Provider<CollectionSharingService>((
  ref,
) {
  return const PlatformCollectionSharingService();
});

String buildCollectionShareText(SongCollection collection, List<Song> songs) {
  final songLabel = songs.length == 1 ? 'song' : 'songs';
  final output = <String>[collection.name, '${songs.length} $songLabel', ''];

  if (songs.isEmpty) {
    output.add('No songs in this list.');
  } else {
    for (var index = 0; index < songs.length; index++) {
      final song = songs[index];
      output.add('${index + 1}. ${song.title}');
      if (_present(song.englishTitle) case final englishTitle?) {
        output.add('   $englishTitle');
      }
      if (_present(song.author) case final author?) {
        output.add('   Author: $author');
      }
    }
  }

  output
    ..add('')
    ..add('Shared from Praise');
  return output.join('\n');
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
