import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collection_sharing_service.dart';
import 'package:praise/features/collections/data/collections_repository.dart';
import 'package:praise/features/collections/presentation/collection_detail_screen.dart';
import 'package:praise/features/collections/presentation/collection_providers.dart';

void main() {
  testWidgets('list export chooses index-only or complete songs', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 15);
    final collection = SongCollection(
      id: 'worship',
      name: 'Sunday Worship',
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FakeCollectionsRepository(collection);
    final sharing = _FakeCollectionSharingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsRepositoryProvider.overrideWithValue(repository),
          collectionSharingServiceProvider.overrideWithValue(sharing),
        ],
        child: const MaterialApp(
          home: CollectionDetailScreen(collectionId: 'worship'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy or share list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Song list only'), findsOneWidget);
    expect(find.text('Full songs'), findsOneWidget);
    await tester.tap(find.text('Full songs'));
    await tester.pumpAndSettle();
    expect(sharing.pdfIncludesSongs, isTrue);

    await tester.tap(find.byTooltip('Copy or share list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song list only'));
    await tester.pumpAndSettle();
    expect(sharing.imageIncludesSongs, isFalse);
  });
}

class _FakeCollectionSharingService implements CollectionSharingService {
  bool? imageIncludesSongs;
  bool? pdfIncludesSongs;

  @override
  Future<void> copyCollection(
    SongCollection collection,
    List<Song> songs,
  ) async {}

  @override
  Future<void> shareCollection(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  }) async {}

  @override
  Future<void> shareCollectionLink(
    SongCollection collection,
    List<Song> songs, {
    Rect? sharePositionOrigin,
  }) async {}

  @override
  Future<void> shareCollectionImage(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  }) async {
    imageIncludesSongs = includeSongs;
  }

  @override
  Future<void> shareCollectionPdf(
    SongCollection collection,
    List<Song> songs, {
    bool includeSongs = false,
    Rect? sharePositionOrigin,
  }) async {
    pdfIncludesSongs = includeSongs;
  }
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
      Stream.value([CollectionSummary(collection: collection, songCount: 0)]);
}
