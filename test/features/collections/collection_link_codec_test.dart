import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collection_link_codec.dart';

void main() {
  test('builds and parses a compact shareable collection link', () {
    final collection = SongCollection(
      id: 'list-1',
      name: 'Sunday Worship',
      isSystem: false,
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
    );
    final songs = [
      Song(
        id: 'csv-0001',
        title: 'One',
        body: 'Body',
        source: 'server',
        createdAt: DateTime.utc(2026, 8, 29),
        updatedAt: DateTime.utc(2026, 8, 29),
        isDeleted: false,
      ),
      Song(
        id: 'csv-0002',
        title: 'Two',
        body: 'Body',
        source: 'server',
        createdAt: DateTime.utc(2026, 8, 29),
        updatedAt: DateTime.utc(2026, 8, 29),
        isDeleted: false,
      ),
    ];

    final link = buildCollectionLink(collection, songs);
    final payload = parseCollectionLink(link);

    expect(link.toString(), contains('/praise-catalog/list?p='));
    expect(payload.name, 'Sunday Worship');
    expect(payload.songIds, ['csv-0001', 'csv-0002']);
  });

  test('parses legacy fragment links', () {
    final current = Uri.parse(
      'https://nani-samireddy.github.io/praise-catalog/list'
      '?p=eyJ2IjoxLCJuYW1lIjoiU3VuZGF5Iiwic29uZ3MiOlsiY3N2LTAwMDEiXX0',
    );
    final legacy = Uri(
      scheme: current.scheme,
      host: current.host,
      path: current.path,
      fragment: current.queryParameters['p'],
    );

    final payload = parseCollectionLink(legacy);

    expect(payload.name, 'Sunday');
    expect(payload.songIds, ['csv-0001']);
  });

  test('rejects unsupported links', () {
    expect(
      () => parseCollectionLink(Uri.parse('https://example.com/list#bad')),
      throwsA(isA<CollectionLinkException>()),
    );
  });
}
