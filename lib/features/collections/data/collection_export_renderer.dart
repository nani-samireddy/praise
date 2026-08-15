import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';

const _imageWidth = 1080.0;
const _imagePadding = 72.0;
const _maximumImageHeight = 12000.0;
const _fontFamily = 'NotoSansTelugu';
const _pdfFontAsset = 'assets/fonts/NotoSansTelugu-Variable.ttf';

class CollectionImageTooLargeException implements Exception {
  const CollectionImageTooLargeException();

  @override
  String toString() => 'The list is too long to render safely as one image.';
}

Future<Uint8List> buildCollectionImageBytes(
  SongCollection collection,
  List<Song> songs,
) async {
  final contentWidth = _imageWidth - (_imagePadding * 2);
  final title = _layoutParagraph(
    collection.name,
    width: contentWidth,
    fontSize: 58,
    fontWeight: ui.FontWeight.w700,
    color: const ui.Color(0xff17151a),
  );
  final count = _layoutParagraph(
    _songCountLabel(songs.length),
    width: contentWidth,
    fontSize: 30,
    color: const ui.Color(0xff6d6772),
  );
  final rows = songs.isEmpty
      ? [
          _layoutParagraph(
            'No songs in this list.',
            width: contentWidth,
            fontSize: 36,
            color: const ui.Color(0xff3d3841),
          ),
        ]
      : [
          for (var index = 0; index < songs.length; index++)
            _layoutParagraph(
              _songEntry(index, songs[index]),
              width: contentWidth,
              fontSize: 36,
              color: const ui.Color(0xff262229),
            ),
        ];
  final footer = _layoutParagraph(
    'Shared from Praise',
    width: contentWidth,
    fontSize: 26,
    color: const ui.Color(0xff766f79),
  );

  const topGap = 18.0;
  const headerBottomGap = 48.0;
  const rowPadding = 26.0;
  const footerTopGap = 44.0;
  var height =
      _imagePadding + title.height + topGap + count.height + headerBottomGap;
  for (final row in rows) {
    height += row.height + (rowPadding * 2) + 1;
  }
  height += footerTopGap + footer.height + _imagePadding;
  height = height.clamp(_imageWidth, _maximumImageHeight + 1);
  if (height > _maximumImageHeight) {
    throw const CollectionImageTooLargeException();
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xfffaf8f4), ui.BlendMode.src);

  var y = _imagePadding;
  canvas.drawParagraph(title, ui.Offset(_imagePadding, y));
  y += title.height + topGap;
  canvas.drawParagraph(count, ui.Offset(_imagePadding, y));
  y += count.height + headerBottomGap;

  final dividerPaint = ui.Paint()
    ..color = const ui.Color(0xffddd7df)
    ..strokeWidth = 1;
  for (final row in rows) {
    y += rowPadding;
    canvas.drawParagraph(row, ui.Offset(_imagePadding, y));
    y += row.height + rowPadding;
    canvas.drawLine(
      ui.Offset(_imagePadding, y),
      ui.Offset(_imageWidth - _imagePadding, y),
      dividerPaint,
    );
    y += 1;
  }

  y += footerTopGap;
  canvas.drawParagraph(footer, ui.Offset(_imagePadding, y));

  final picture = recorder.endRecording();
  final image = await picture.toImage(_imageWidth.toInt(), height.ceil());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode the list image.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> buildCollectionPdfBytes(
  SongCollection collection,
  List<Song> songs,
) async {
  final fontData = await rootBundle.load(_pdfFontAsset);
  final font = pw.Font.ttf(fontData);
  final document = pw.Document(
    title: collection.name,
    author: 'Praise',
    creator: 'Praise',
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 46, 42, 42),
      maxPages: 100,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Text(
                collection.name,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xff6d6772),
                ),
              ),
            ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Shared from Praise',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff766f79),
              ),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff766f79),
              ),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Text(collection.name, style: pw.TextStyle(font: font, fontSize: 26)),
        pw.SizedBox(height: 6),
        pw.Text(
          _songCountLabel(songs.length),
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColor.fromInt(0xff6d6772),
          ),
        ),
        pw.SizedBox(height: 22),
        if (songs.isEmpty)
          pw.Text('No songs in this list.')
        else
          for (var index = 0; index < songs.length; index++)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xffddd7df),
                    width: 0.6,
                  ),
                ),
              ),
              child: pw.Text(
                _songEntry(index, songs[index]),
                style: pw.TextStyle(font: font, fontSize: 13, lineSpacing: 3),
              ),
            ),
      ],
    ),
  );
  return document.save();
}

String collectionExportFileName(String name, String extension) {
  var safe = name
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (safe.isEmpty) safe = 'Praise list';
  if (safe.length > 80) safe = safe.substring(0, 80).trimRight();
  return '$safe.$extension';
}

ui.Paragraph _layoutParagraph(
  String text, {
  required double width,
  required double fontSize,
  required ui.Color color,
  ui.FontWeight fontWeight = ui.FontWeight.w400,
}) {
  final builder =
      ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontFamily: _fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.3,
        ),
      )..pushStyle(
        ui.TextStyle(
          color: color,
          fontFamily: _fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      );
  builder.addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

String _songCountLabel(int count) => '$count ${count == 1 ? 'song' : 'songs'}';

String _songEntry(int index, Song song) {
  final lines = <String>['${index + 1}. ${song.title.trim()}'];
  if (_present(song.englishTitle) case final englishTitle?) {
    lines.add(englishTitle);
  }
  if (_present(song.author) case final author?) {
    lines.add('Author: $author');
  }
  return lines.join('\n');
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
