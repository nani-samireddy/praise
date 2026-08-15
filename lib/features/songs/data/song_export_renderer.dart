import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import 'song_share_formatter.dart';

Future<Uint8List> buildSongImageBytes(Song song) {
  return renderExportDocumentImage(buildSongExportDocument(song));
}

Future<Uint8List> buildSongPdfBytes(Song song) async {
  if (song.imagePath case final imagePath?) {
    final file = File(imagePath);
    if (await file.exists()) {
      return _buildPhotoSongPdf(song, await file.readAsBytes());
    }
  }
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
      if (song.body.trim().isNotEmpty)
        ExportSection(
          title: hasEnglish ? 'Primary lyrics' : 'Lyrics',
          body: formatLyricsForSharing(song.body),
        )
      else if (song.imagePath != null)
        const ExportSection(
          title: 'Photo song',
          body: 'Original lyrics are stored as a photo in Praise.',
        ),
      if (_present(song.englishBody) case final englishBody?)
        ExportSection(
          title: 'English lyrics',
          body: formatLyricsForSharing(englishBody),
        ),
    ],
  );
}

Future<Uint8List> _buildPhotoSongPdf(Song song, Uint8List imageBytes) async {
  final fontData = await rootBundle.load(
    'assets/fonts/NotoSansTelugu-Variable.ttf',
  );
  final font = pw.Font.ttf(fontData);
  final pdf = pw.Document(
    title: song.title,
    author: 'Praise',
    creator: 'Praise',
  );
  final details = [
    ?_present(song.englishTitle),
    if (_present(song.author) case final author?) 'Author: $author',
  ].join('\n');
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 46, 42, 42),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(song.title, style: pw.TextStyle(font: font, fontSize: 26)),
          if (details.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              details,
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColor.fromInt(0xff6d6772),
              ),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Expanded(
            child: pw.Center(
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Shared from Praise',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xff766f79),
            ),
          ),
        ],
      ),
    ),
  );
  return pdf.save();
}

String songExportFileName(String name, String extension) {
  return exportFileName(name, extension);
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
