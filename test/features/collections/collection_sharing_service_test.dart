import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collection_sharing_service.dart';

void main() {
  test('builds an ordered bilingual list with authors', () {
    final now = DateTime.utc(2026, 8, 15);
    final collection = SongCollection(
      id: 'sunday',
      name: 'Sunday Worship',
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    );
    final songs = [
      Song(
        id: 'one',
        title: 'మొదటి పాట',
        englishTitle: 'First Song',
        body: 'Lyrics',
        englishBody: null,
        author: 'Author One',
        source: 'server',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      ),
      Song(
        id: 'two',
        title: 'రెండవ పాట',
        englishTitle: null,
        body: 'Lyrics',
        englishBody: null,
        author: null,
        source: 'server',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      ),
    ];

    expect(buildCollectionShareText(collection, songs), '''Sunday Worship
2 songs

1. మొదటి పాట
   First Song
   Author: Author One
2. రెండవ పాట

Shared from Praise''');
  });

  test('builds readable text for an empty list', () {
    final now = DateTime.utc(2026, 8, 15);
    final collection = SongCollection(
      id: 'empty',
      name: 'Prayer',
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    );

    expect(buildCollectionShareText(collection, const []), '''Prayer
0 songs

No songs in this list.

Shared from Praise''');
  });
}
