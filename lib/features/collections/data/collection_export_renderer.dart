import 'dart:typed_data';

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import '../../songs/data/song_share_formatter.dart';

Future<Uint8List> buildCollectionImageBytes(
  SongCollection collection,
  List<Song> songs, {
  bool includeSongs = false,
}) {
  return renderExportDocumentImage(
    buildCollectionExportDocument(
      collection,
      songs,
      includeSongs: includeSongs,
    ),
  );
}

Future<Uint8List> buildCollectionPdfBytes(
  SongCollection collection,
  List<Song> songs, {
  bool includeSongs = false,
}) {
  return renderExportDocumentPdf(
    buildCollectionExportDocument(
      collection,
      songs,
      includeSongs: includeSongs,
    ),
  );
}

ExportDocument buildCollectionExportDocument(
  SongCollection collection,
  List<Song> songs, {
  bool includeSongs = false,
}) {
  return ExportDocument(
    title: collection.name,
    subtitle:
        '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}${includeSongs ? ' • Full lyrics' : ''}',
    sections: songs.isEmpty
        ? const [ExportSection(body: 'No songs in this list.')]
        : [
            for (var index = 0; index < songs.length; index++)
              includeSongs
                  ? _fullSongSection(index, songs[index])
                  : _songIndexSection(index, songs[index]),
          ],
  );
}

String collectionExportFileName(
  String name,
  String extension, {
  bool includeSongs = false,
}) {
  if (name.trim().isEmpty) return exportFileName('Praise list', extension);
  final suffix = includeSongs ? ' - full songs' : '';
  return exportFileName('$name$suffix', extension);
}

ExportSection _songIndexSection(int index, Song song) {
  final details = <String>[];
  if (_present(song.englishTitle) case final englishTitle?) {
    details.add(englishTitle);
  }
  if (_present(song.author) case final author?) {
    details.add('Author: $author');
  }
  return ExportSection(
    title: '${index + 1}. ${song.title.trim()}',
    body: details.join('\n'),
  );
}

ExportSection _fullSongSection(int index, Song song) {
  final body = <String>[];
  if (_present(song.englishTitle) case final englishTitle?) {
    body.add(englishTitle);
  }
  if (_present(song.author) case final author?) {
    body.add('Author: $author');
  }
  body
    ..add(song.imagePath == null ? 'LYRICS' : 'PHOTO SONG')
    ..add(
      song.body.trim().isNotEmpty
          ? formatLyricsForSharing(song.body)
          : 'Original lyrics are stored as a photo in Praise.',
    );
  if (_present(song.englishBody) case final englishBody?) {
    body
      ..add('ENGLISH LYRICS')
      ..add(formatLyricsForSharing(englishBody));
  }
  return ExportSection(
    title: '${index + 1}. ${song.title.trim()}',
    body: body.join('\n\n'),
    pageBreakBefore: index > 0,
  );
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
