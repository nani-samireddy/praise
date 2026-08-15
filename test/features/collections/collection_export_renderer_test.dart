import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collection_export_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a valid PNG and PDF with Telugu text', (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 8, 15);
      final collection = SongCollection(
        id: 'worship',
        name: 'ఆరాధన పాటలు',
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      );
      final songs = [
        Song(
          id: 'one',
          title: 'పదే పదే నేను పాడుకోనా',
          englishTitle: 'Again and Again',
          body: 'Lyrics',
          englishBody: null,
          author: 'Praise',
          source: 'local',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        Song(
          id: 'two',
          title: 'రెండవ పాట',
          englishTitle: 'Second Song',
          body: 'రెండవ పాట సాహిత్యం',
          englishBody: 'Second song lyrics',
          author: null,
          source: 'local',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
      ];

      final png = await buildCollectionImageBytes(
        collection,
        songs,
        includeSongs: true,
      );
      final pdf = await buildCollectionPdfBytes(
        collection,
        songs,
        includeSongs: true,
      );

      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      final document = buildCollectionExportDocument(
        collection,
        songs,
        includeSongs: true,
      );
      expect(document.subtitle, contains('Full lyrics'));
      expect(document.sections, hasLength(2));
      expect(document.sections.first.body, contains('Lyrics'));
      expect(document.sections.last.pageBreakBefore, isTrue);
    });
  });

  test('creates safe export file names', () {
    expect(
      collectionExportFileName('  Sunday: Worship / Songs?  ', 'pdf'),
      'Sunday- Worship - Songs-.pdf',
    );
    expect(collectionExportFileName('   ', 'png'), 'Praise list.png');
    expect(
      collectionExportFileName('Worship', 'pdf', includeSongs: true),
      'Worship - full songs.pdf',
    );
  });
}
