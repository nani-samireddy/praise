import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collection_link_codec.dart';

void main() {
  Uri link(Object payload) => Uri(
    scheme: 'praise',
    host: 'list',
    queryParameters: {'p': base64Url.encode(utf8.encode(jsonEncode(payload)))},
  );
  test('reports duplicates while preserving first occurrence order', () {
    final result = parseCollectionLink(
      link({
        'v': 1,
        'name': 'List',
        'songs': ['two', 'one', 'two'],
      }),
    );
    expect(result.songIds, ['two', 'one']);
    expect(result.duplicateCount, 1);
  });
  test('rejects empty, oversized and unsupported payloads', () {
    for (final payload in [
      {'v': 1, 'name': 'List', 'songs': []},
      {
        'v': 2,
        'name': 'List',
        'songs': ['one'],
      },
      {'v': 1, 'name': 'List', 'songs': List.generate(301, (i) => '$i')},
    ]) {
      expect(
        () => parseCollectionLink(link(payload)),
        throwsA(isA<CollectionLinkException>()),
      );
    }
    expect(
      () => parseCollectionLink(Uri.parse('praise://list')),
      throwsA(isA<CollectionLinkException>()),
    );
  });

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

    expect(
      () => buildCollectionLink(
        collection,
        List.generate(301, (i) => songs.first.copyWith(id: 'song-$i')),
      ),
      throwsA(isA<CollectionLinkException>()),
    );
    expect(
      () => buildCollectionLink(collection.copyWith(name: 'x' * 13000), songs),
      throwsA(isA<CollectionLinkException>()),
    );
    expect(
      () => buildCollectionLink(collection, []),
      throwsA(isA<CollectionLinkException>()),
    );
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
