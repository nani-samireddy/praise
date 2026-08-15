import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _imageWidth = 1080.0;
const _imagePadding = 72.0;
const _maximumImageHeight = 12000.0;
const _fontFamily = 'NotoSansTelugu';
const _pdfFontAsset = 'assets/fonts/NotoSansTelugu-Variable.ttf';

class ExportDocument {
  const ExportDocument({
    required this.title,
    this.subtitle,
    required this.sections,
  });

  final String title;
  final String? subtitle;
  final List<ExportSection> sections;
}

class ExportSection {
  const ExportSection({
    this.title,
    required this.body,
    this.pageBreakBefore = false,
  });

  final String? title;
  final String body;
  final bool pageBreakBefore;
}

class ExportImageTooLargeException implements Exception {
  const ExportImageTooLargeException();

  @override
  String toString() => 'The content is too long to render safely as one image.';
}

Future<Uint8List> renderExportDocumentImage(ExportDocument document) async {
  final contentWidth = _imageWidth - (_imagePadding * 2);
  final title = _layoutParagraph(
    document.title,
    width: contentWidth,
    fontSize: 58,
    fontWeight: ui.FontWeight.w700,
    color: const ui.Color(0xff17151a),
  );
  final subtitle = _layoutOptionalParagraph(
    document.subtitle,
    width: contentWidth,
    fontSize: 30,
    color: const ui.Color(0xff6d6772),
  );
  final sections = [
    for (final section in document.sections)
      _ImageSection(
        title: _layoutOptionalParagraph(
          section.title,
          width: contentWidth,
          fontSize: 34,
          fontWeight: ui.FontWeight.w700,
          color: const ui.Color(0xff5d3d69),
        ),
        body: _layoutOptionalParagraph(
          section.body,
          width: contentWidth,
          fontSize: 32,
          color: const ui.Color(0xff262229),
        ),
        pageBreakBefore: section.pageBreakBefore,
      ),
  ];
  final footer = _layoutParagraph(
    'Shared from Praise',
    width: contentWidth,
    fontSize: 26,
    color: const ui.Color(0xff766f79),
  );

  var height = _imagePadding + title.height;
  if (subtitle != null) height += 18 + subtitle.height;
  height += 42;
  for (final section in sections) {
    height += section.pageBreakBefore ? 48 : 26;
    if (section.title != null) height += section.title!.height + 18;
    if (section.body != null) height += section.body!.height;
    height += 30 + 1;
  }
  height += 44 + footer.height + _imagePadding;
  height = height.clamp(_imageWidth, _maximumImageHeight + 1);
  if (height > _maximumImageHeight) {
    throw const ExportImageTooLargeException();
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xfffaf8f4), ui.BlendMode.src);

  var y = _imagePadding;
  canvas.drawParagraph(title, ui.Offset(_imagePadding, y));
  y += title.height;
  if (subtitle != null) {
    y += 18;
    canvas.drawParagraph(subtitle, ui.Offset(_imagePadding, y));
    y += subtitle.height;
  }
  y += 42;

  final dividerPaint = ui.Paint()
    ..color = const ui.Color(0xffddd7df)
    ..strokeWidth = 1;
  for (final section in sections) {
    y += section.pageBreakBefore ? 48 : 26;
    if (section.title != null) {
      canvas.drawParagraph(section.title!, ui.Offset(_imagePadding, y));
      y += section.title!.height + 18;
    }
    if (section.body != null) {
      canvas.drawParagraph(section.body!, ui.Offset(_imagePadding, y));
      y += section.body!.height;
    }
    y += 30;
    canvas.drawLine(
      ui.Offset(_imagePadding, y),
      ui.Offset(_imageWidth - _imagePadding, y),
      dividerPaint,
    );
    y += 1;
  }

  y += 44;
  canvas.drawParagraph(footer, ui.Offset(_imagePadding, y));

  final picture = recorder.endRecording();
  final image = await picture.toImage(_imageWidth.toInt(), height.ceil());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode the export image.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> renderExportDocumentPdf(ExportDocument document) async {
  final fontData = await rootBundle.load(_pdfFontAsset);
  final font = pw.Font.ttf(fontData);
  final pdf = pw.Document(
    title: document.title,
    author: 'Praise',
    creator: 'Praise',
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 46, 42, 42),
      maxPages: 500,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Text(
                document.title,
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
        pw.Text(document.title, style: pw.TextStyle(font: font, fontSize: 26)),
        if (_present(document.subtitle) case final subtitle?) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColor.fromInt(0xff6d6772),
            ),
          ),
        ],
        pw.SizedBox(height: 22),
        for (var index = 0; index < document.sections.length; index++) ...[
          if (index > 0 && document.sections[index].pageBreakBefore)
            pw.NewPage(),
          if (_present(document.sections[index].title) case final title?) ...[
            pw.Text(title, style: pw.TextStyle(font: font, fontSize: 17)),
            pw.SizedBox(height: 10),
          ],
          for (final paragraph in _paragraphs(
            document.sections[index].body,
          )) ...[
            pw.Text(
              paragraph,
              style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 3),
            ),
            pw.SizedBox(height: 12),
          ],
          if (index < document.sections.length - 1)
            pw.Divider(color: const PdfColor.fromInt(0xffddd7df)),
          if (index < document.sections.length - 1) pw.SizedBox(height: 16),
        ],
      ],
    ),
  );
  return pdf.save();
}

String exportFileName(String name, String extension) {
  var safe = name
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (safe.isEmpty) safe = 'Praise export';
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
          height: 1.4,
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

ui.Paragraph? _layoutOptionalParagraph(
  String? text, {
  required double width,
  required double fontSize,
  required ui.Color color,
  ui.FontWeight fontWeight = ui.FontWeight.w400,
}) {
  final value = _present(text);
  if (value == null) return null;
  return _layoutParagraph(
    value,
    width: width,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
}

Iterable<String> _paragraphs(String body) => body
    .trim()
    .split(RegExp(r'\n{2,}'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty);

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _ImageSection {
  const _ImageSection({
    required this.title,
    required this.body,
    required this.pageBreakBefore,
  });

  final ui.Paragraph? title;
  final ui.Paragraph? body;
  final bool pageBreakBefore;
}
