import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/catalogue_sync/data/catalogue_models.dart';
import 'package:praise/features/catalogue_sync/data/catalogue_remote_data_source.dart';
import 'package:praise/features/catalogue_sync/data/catalogue_store.dart';
import 'package:praise/features/catalogue_sync/data/catalogue_sync_service.dart';

void main() {
  late AppDatabase database;
  late CatalogueStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = CatalogueStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'snapshot updates server songs and preserves all user-owned data',
    () async {
      final now = DateTime.utc(2026, 8, 1);
      await database.batch((batch) {
        batch.insertAll(database.songs, [
          SongsCompanion.insert(
            id: 'retained',
            title: 'Old title',
            body: 'Old body',
            createdAt: now,
            updatedAt: now,
          ),
          SongsCompanion.insert(
            id: 'removed',
            title: 'Removed title',
            body: 'Removed body',
            createdAt: now,
            updatedAt: now,
          ),
          SongsCompanion.insert(
            id: 'custom-conflict',
            title: 'My conflicting song',
            body: 'My body',
            source: const Value('custom'),
            createdAt: now,
            updatedAt: now,
          ),
          SongsCompanion.insert(
            id: 'custom-safe',
            title: 'My safe song',
            body: 'My other body',
            source: const Value('custom'),
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        batch.insert(
          database.favorites,
          FavoritesCompanion.insert(songId: 'retained', createdAt: now),
        );
        batch.insert(
          database.collections,
          CollectionsCompanion.insert(
            id: 'sunday',
            name: 'Sunday',
            createdAt: now,
            updatedAt: now,
          ),
        );
        batch.insert(
          database.collectionSongs,
          CollectionSongsCompanion.insert(
            collectionId: 'sunday',
            songId: 'retained',
            sortOrder: 0,
            createdAt: now,
          ),
        );
      });

      final manifest = _manifest(version: 2, songCount: 3);
      final snapshot = CatalogueSnapshot(
        manifest: manifest,
        songs: const [
          CatalogueSong(id: 'retained', title: 'New title', body: 'New body'),
          CatalogueSong(
            id: 'new',
            title: 'New song',
            body: 'New song body',
            maleVideoUrl: 'https://www.youtube.com/watch?v=male1234567',
            femaleVideoUrl: 'https://youtu.be/female12345',
          ),
          CatalogueSong(
            id: 'custom-conflict',
            title: 'Server title',
            body: 'Server body',
          ),
        ],
      );
      final service = _service(
        store,
        _FakeRemote(manifest: manifest, snapshot: snapshot),
      );

      final result = await service.sync();

      expect(result.outcome, CatalogueSyncOutcome.updated);
      expect(result.songCount, 2);
      expect(result.skippedCustomConflicts, 1);

      final songs = {
        for (final song in await database.select(database.songs).get())
          song.id: song,
      };
      expect(songs['retained']?.title, 'New title');
      expect(songs['retained']?.isDeleted, isFalse);
      expect(songs['new']?.source, 'server');
      expect(songs['new']?.maleVideoUrl, contains('youtube.com'));
      expect(songs['new']?.femaleVideoUrl, contains('youtu.be'));
      expect(songs['removed']?.isDeleted, isTrue);
      expect(songs['custom-conflict']?.title, 'My conflicting song');
      expect(songs['custom-conflict']?.source, 'custom');
      expect(songs['custom-safe']?.isDeleted, isFalse);
      expect(await database.select(database.favorites).get(), hasLength(1));
      expect(
        await database.select(database.collectionSongs).get(),
        hasLength(1),
      );
      expect(await store.readCatalogueVersion(), 2);
    },
  );

  test('invalid download changes neither songs nor sync metadata', () async {
    final now = DateTime.utc(2026, 8, 1);
    await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            id: 'cached',
            title: 'Cached title',
            body: 'Cached body',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final manifest = _manifest(version: 2, songCount: 1);
    final service = _service(
      store,
      _FakeRemote(
        manifest: manifest,
        error: const CatalogueValidationException('Bad checksum'),
      ),
    );

    await expectLater(service.sync(), throwsA(isA<CatalogueSyncException>()));

    final song = await database.select(database.songs).getSingle();
    expect(song.title, 'Cached title');
    expect(song.isDeleted, isFalse);
    expect(await store.readCatalogueVersion(), isNull);
  });

  test('matching version skips the large catalogue download', () async {
    final manifest = _manifest(version: 1, songCount: 1374);
    await store.recordSuccessfulCheck(manifest);
    final remote = _FakeRemote(manifest: manifest);
    final service = _service(store, remote);

    final result = await service.sync();

    expect(result.outcome, CatalogueSyncOutcome.upToDate);
    expect(remote.catalogueFetches, 0);
  });

  test('catalogue parser rejects duplicate song IDs', () {
    final bytes = utf8.encode(
      jsonEncode([
        {'id': 'same', 'title': 'One', 'body': 'Body'},
        {'id': 'same', 'title': 'Two', 'body': 'Body'},
      ]),
    );

    expect(
      () => CatalogueSnapshot.fromBytes(
        manifest: _manifest(version: 1, songCount: 2),
        bytes: bytes,
      ),
      throwsA(isA<CatalogueValidationException>()),
    );
  });
}

CatalogueSyncService _service(
  CatalogueStore store,
  CatalogueRemoteDataSource remote,
) {
  return CatalogueSyncService(
    manifestUrl: 'https://example.test/catalog/manifest.json',
    remote: remote,
    store: store,
  );
}

CatalogueManifest _manifest({required int version, required int songCount}) {
  return CatalogueManifest(
    schemaVersion: 1,
    catalogueVersion: version,
    generatedAt: DateTime.utc(2026, 8, 13),
    songCount: songCount,
    sha256: 'a' * 64,
    catalogueUrl: 'songs.json',
  );
}

class _FakeRemote implements CatalogueRemoteDataSource {
  _FakeRemote({required this.manifest, this.snapshot, this.error});

  final CatalogueManifest manifest;
  final CatalogueSnapshot? snapshot;
  final Object? error;
  int catalogueFetches = 0;

  @override
  Future<CatalogueSnapshot> fetchCatalogue(
    Uri manifestUri,
    CatalogueManifest manifest,
  ) async {
    catalogueFetches++;
    if (error case final error?) throw error;
    return snapshot!;
  }

  @override
  Future<CatalogueManifest> fetchManifest(Uri manifestUri) async => manifest;
}
