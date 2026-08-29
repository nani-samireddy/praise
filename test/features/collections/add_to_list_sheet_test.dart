import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collections_repository.dart';
import 'package:praise/features/collections/presentation/add_to_list_sheet.dart';
import 'package:praise/features/collections/presentation/collection_providers.dart';

void main() {
  testWidgets('add-to-list sheet lays out existing lists without errors', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 13);
    final repository = _FakeCollectionsRepository(
      SongCollection(
        id: 'list',
        name: 'Sunday Worship',
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const AddToListSheet(songId: 'song'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Create new list'), findsOneWidget);
    expect(find.text('Sunday Worship'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCollectionsRepository implements CollectionsRepository {
  const _FakeCollectionsRepository(this.collection);

  final SongCollection collection;

  @override
  Future<void> addSong(String collectionId, String songId) async {}

  @override
  Future<String> createCollection(String name) async => collection.id;

  @override
  Future<String> importCollection({
    required String name,
    required List<String> songIds,
  }) async => collection.id;

  @override
  Future<void> deleteCollection(String id) async {}

  @override
  Future<void> removeSong(String collectionId, String songId) async {}

  @override
  Future<void> renameCollection(String id, String name) async {}

  @override
  Future<void> reorderSongs(String collectionId, List<String> songIds) async {}

  @override
  Stream<SongCollection?> watchCollection(String id) =>
      Stream.value(collection);

  @override
  Stream<Set<String>> watchCollectionIdsForSong(String songId) =>
      Stream.value(<String>{});

  @override
  Stream<List<Song>> watchCollectionSongs(String id) => Stream.value(const []);

  @override
  Stream<List<CollectionSummary>> watchCollections() =>
      Stream.value([CollectionSummary(collection: collection, songCount: 1)]);
}
