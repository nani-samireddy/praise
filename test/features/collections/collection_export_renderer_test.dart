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
      ];

      final png = await buildCollectionImageBytes(collection, songs);
      final pdf = await buildCollectionPdfBytes(collection, songs);

      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    });
  });

  test('creates safe export file names', () {
    expect(
      collectionExportFileName('  Sunday: Worship / Songs?  ', 'pdf'),
      'Sunday- Worship - Songs-.pdf',
    );
    expect(collectionExportFileName('   ', 'png'), 'Praise list.png');
  });
}
