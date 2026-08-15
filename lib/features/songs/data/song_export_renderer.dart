import 'dart:typed_data';

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import 'song_share_formatter.dart';

Future<Uint8List> buildSongImageBytes(Song song) {
  return renderExportDocumentImage(buildSongExportDocument(song));
}

Future<Uint8List> buildSongPdfBytes(Song song) {
  return renderExportDocumentPdf(buildSongExportDocument(song));
}

ExportDocument buildSongExportDocument(Song song) {
  final subtitle = <String>[];
  if (_present(song.englishTitle) case final englishTitle?) {
    subtitle.add(englishTitle);
  }
  if (_present(song.author) case final author?) {
    subtitle.add('Author: $author');
  }
  final hasEnglish = _present(song.englishBody) != null;
  return ExportDocument(
    title: song.title,
    subtitle: subtitle.join('\n'),
    sections: [
      ExportSection(
        title: hasEnglish ? 'Primary lyrics' : 'Lyrics',
        body: formatLyricsForSharing(song.body),
      ),
      if (_present(song.englishBody) case final englishBody?)
        ExportSection(
          title: 'English lyrics',
          body: formatLyricsForSharing(englishBody),
        ),
    ],
  );
}

String songExportFileName(String name, String extension) {
  return exportFileName(name, extension);
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
