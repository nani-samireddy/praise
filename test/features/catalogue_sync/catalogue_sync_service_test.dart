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

  test('matching delta version applies only changed songs', () async {
    final now = DateTime.utc(2026, 8, 1);
    await database.batch((batch) {
      batch.insertAll(database.songs, [
        SongsCompanion.insert(
          id: 'changed',
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
          id: 'unchanged',
          title: 'Same title',
          body: 'Same body',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    });
    await store.recordSuccessfulCheck(_manifest(version: 1, songCount: 3));
    final manifest = _manifest(version: 2, songCount: 3, deltaFromVersion: 1);
    final remote = _FakeRemote(
      manifest: manifest,
      delta: const CatalogueDelta(
        fromVersion: 1,
        toVersion: 2,
        upserts: [
          CatalogueSong(id: 'changed', title: 'New title', body: 'New body'),
          CatalogueSong(id: 'new', title: 'New song', body: 'New body'),
        ],
        deletes: ['removed'],
      ),
    );
    final service = _service(store, remote);

    final result = await service.sync();

    expect(result.outcome, CatalogueSyncOutcome.updated);
    expect(result.catalogueVersion, 2);
    expect(result.songCount, 3);
    expect(remote.deltaFetches, 1);
    expect(remote.catalogueFetches, 0);

    final songs = {
      for (final song in await database.select(database.songs).get())
        song.id: song,
    };
    expect(songs['changed']?.title, 'New title');
    expect(songs['new']?.isDeleted, isFalse);
    expect(songs['removed']?.isDeleted, isTrue);
    expect(songs['unchanged']?.isDeleted, isFalse);
    expect(await store.readCatalogueVersion(), 2);
  });

  test('continuous delta chain syncs from older local versions', () async {
    final now = DateTime.utc(2026, 8, 1);
    await database.batch((batch) {
      batch.insertAll(database.songs, [
        SongsCompanion.insert(
          id: 'edited-later',
          title: 'Old title',
          body: 'Old body',
          createdAt: now,
          updatedAt: now,
        ),
        SongsCompanion.insert(
          id: 'removed-middle',
          title: 'Removed title',
          body: 'Removed body',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    });
    await store.recordSuccessfulCheck(_manifest(version: 7, songCount: 2));
    final manifest = _manifest(
      version: 10,
      songCount: 3,
      deltas: const [
        CatalogueDeltaReference(
          fromVersion: 7,
          toVersion: 8,
          sha256: 'b',
          url: 'delta-v7-v8.json',
        ),
        CatalogueDeltaReference(
          fromVersion: 8,
          toVersion: 9,
          sha256: 'c',
          url: 'delta-v8-v9.json',
        ),
        CatalogueDeltaReference(
          fromVersion: 9,
          toVersion: 10,
          sha256: 'd',
          url: 'delta-v9-v10.json',
        ),
      ],
    );
    final remote = _FakeRemote(
      manifest: manifest,
      deltas: const {
        'delta-v7-v8.json': CatalogueDelta(
          fromVersion: 7,
          toVersion: 8,
          upserts: [
            CatalogueSong(id: 'added-first', title: 'Added', body: 'Body'),
          ],
          deletes: [],
        ),
        'delta-v8-v9.json': CatalogueDelta(
          fromVersion: 8,
          toVersion: 9,
          upserts: [],
          deletes: ['removed-middle'],
        ),
        'delta-v9-v10.json': CatalogueDelta(
          fromVersion: 9,
          toVersion: 10,
          upserts: [
            CatalogueSong(
              id: 'edited-later',
              title: 'New title',
              body: 'New body',
            ),
            CatalogueSong(id: 'added-last', title: 'Last', body: 'Body'),
          ],
          deletes: [],
        ),
      },
    );
    final service = _service(store, remote);

    final result = await service.sync();

    expect(result.outcome, CatalogueSyncOutcome.updated);
    expect(result.catalogueVersion, 10);
    expect(result.songCount, 3);
    expect(remote.deltaFetches, 3);
    expect(remote.catalogueFetches, 0);

    final songs = {
      for (final song in await database.select(database.songs).get())
        song.id: song,
    };
    expect(songs['added-first']?.isDeleted, isFalse);
    expect(songs['added-last']?.isDeleted, isFalse);
    expect(songs['edited-later']?.title, 'New title');
    expect(songs['removed-middle']?.isDeleted, isTrue);
    expect(await store.readCatalogueVersion(), 10);
  });

  test('missing delta chain falls back to full snapshot', () async {
    await store.recordSuccessfulCheck(_manifest(version: 1, songCount: 1));
    final manifest = _manifest(version: 3, songCount: 1, deltaFromVersion: 2);
    final snapshot = CatalogueSnapshot(
      manifest: manifest,
      songs: const [
        CatalogueSong(id: 'fresh', title: 'Fresh title', body: 'Fresh body'),
      ],
    );
    final remote = _FakeRemote(manifest: manifest, snapshot: snapshot);
    final service = _service(store, remote);

    final result = await service.sync();

    expect(result.outcome, CatalogueSyncOutcome.updated);
    expect(remote.deltaFetches, 0);
    expect(remote.catalogueFetches, 1);
    expect(await store.readCatalogueVersion(), 3);
  });

  test('invalid delta falls back to full snapshot', () async {
    await store.recordSuccessfulCheck(_manifest(version: 1, songCount: 1));
    final manifest = _manifest(version: 2, songCount: 1, deltaFromVersion: 1);
    final snapshot = CatalogueSnapshot(
      manifest: manifest,
      songs: const [
        CatalogueSong(id: 'fresh', title: 'Fresh title', body: 'Fresh body'),
      ],
    );
    final remote = _FakeRemote(
      manifest: manifest,
      snapshot: snapshot,
      deltaError: const CatalogueValidationException('Bad delta'),
    );
    final service = _service(store, remote);

    final result = await service.sync();

    expect(result.outcome, CatalogueSyncOutcome.updated);
    expect(remote.deltaFetches, 1);
    expect(remote.catalogueFetches, 1);
    expect(await store.readCatalogueVersion(), 2);
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

CatalogueManifest _manifest({
  required int version,
  required int songCount,
  int? deltaFromVersion,
  List<CatalogueDeltaReference> deltas = const [],
}) {
  return CatalogueManifest(
    schemaVersion: 1,
    catalogueVersion: version,
    generatedAt: DateTime.utc(2026, 8, 13),
    songCount: songCount,
    sha256: 'a' * 64,
    catalogueUrl: 'songs.json',
    deltaFromVersion: deltaFromVersion,
    deltaSha256: deltaFromVersion == null ? null : 'b' * 64,
    deltaUrl: deltaFromVersion == null
        ? null
        : 'delta-v$deltaFromVersion-v$version.json',
    deltas: deltas,
  );
}

class _FakeRemote implements CatalogueRemoteDataSource {
  _FakeRemote({
    required this.manifest,
    this.snapshot,
    this.delta,
    this.deltas = const {},
    this.error,
    this.deltaError,
  });

  final CatalogueManifest manifest;
  final CatalogueSnapshot? snapshot;
  final CatalogueDelta? delta;
  final Map<String, CatalogueDelta> deltas;
  final Object? error;
  final Object? deltaError;
  int catalogueFetches = 0;
  int deltaFetches = 0;

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
  Future<CatalogueDelta> fetchDelta(
    Uri manifestUri,
    CatalogueDeltaReference reference,
  ) async {
    deltaFetches++;
    if (deltaError case final error?) throw error;
    return deltas[reference.url] ?? delta!;
  }

  @override
  Future<CatalogueManifest> fetchManifest(Uri manifestUri) async => manifest;
}
