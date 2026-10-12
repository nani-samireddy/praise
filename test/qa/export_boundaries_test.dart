import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/export/export_document_renderer.dart';

import 'ui_qa_fixture.dart';

void main() {
  testWidgets('long bilingual document paginates and rejects oversized image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final document = ExportDocument(
        title: qaTeluguTitle,
        subtitle: qaEnglishTitle,
        sections: [
          ExportSection(
            title: 'Original lyrics',
            body: List.generate(
              100,
              (i) => '${i + 1}. $qaTeluguTitle\n$qaTeluguTitle',
            ).join('\n\n'),
          ),
          ExportSection(
            title: 'English lyrics',
            pageBreakBefore: true,
            body: List.generate(
              100,
              (i) => '${i + 1}. $qaEnglishTitle',
            ).join('\n\n'),
          ),
        ],
      );
      final pdf = await renderExportDocumentPdf(document);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      // Page objects are uncompressed even when content streams are compressed.
      final pageCount = RegExp(r'/Type\s*/Page\b')
          .allMatches(String.fromCharCodes(pdf))
          .length;
      expect(pageCount, greaterThan(2));
      await expectLater(
        renderExportDocumentImage(document),
        throwsA(isA<ExportImageTooLargeException>()),
      );
      // Opt-in review artifact; ordinary tests write nothing to the workspace.
      final output = Platform.environment['PRAISE_QA_EXPORT_DIR'];
      if (output != null) {
        final directory = await Directory(output).create(recursive: true);
        await File('${directory.path}/long-bilingual.pdf').writeAsBytes(pdf);
      }
    });
  });
}
