import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'catalogue_models.dart';

class CatalogueStatus {
  const CatalogueStatus({
    required this.catalogueVersion,
    required this.lastSuccessfulSync,
  });

  final int? catalogueVersion;
  final DateTime? lastSuccessfulSync;
}

class CatalogueApplyResult {
  const CatalogueApplyResult({
    required this.activeSongCount,
    required this.skippedCustomConflicts,
  });

  final int activeSongCount;
  final int skippedCustomConflicts;
}

class CatalogueStore {
  const CatalogueStore(this._database);

  static const catalogueVersionKey = 'remote_catalogue_version';
  static const catalogueHashKey = 'remote_catalogue_sha256';
  static const lastSuccessfulSyncKey = 'last_catalogue_sync_at';

  final AppDatabase _database;

  Future<int?> readCatalogueVersion() async {
    final value = await _readValue(catalogueVersionKey);
    return int.tryParse(value ?? '');
  }

  Stream<CatalogueStatus> watchStatus() {
    return (_database.select(_database.appMetadata)..where(
          (row) => row.key.isIn([catalogueVersionKey, lastSuccessfulSyncKey]),
        ))
        .watch()
        .map((rows) {
          final values = {for (final row in rows) row.key: row.value};
          return CatalogueStatus(
            catalogueVersion: int.tryParse(values[catalogueVersionKey] ?? ''),
            lastSuccessfulSync: DateTime.tryParse(
              values[lastSuccessfulSyncKey] ?? '',
            )?.toLocal(),
          );
        });
  }

  Future<void> recordSuccessfulCheck(CatalogueManifest manifest) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _writeMetadata(catalogueVersionKey, manifest.catalogueVersion, now);
      await _writeMetadata(catalogueHashKey, manifest.sha256, now);
      await _writeMetadata(lastSuccessfulSyncKey, now.toIso8601String(), now);
    });
  }

  Future<CatalogueApplyResult> apply(CatalogueSnapshot snapshot) async {
    final now = DateTime.now().toUtc();
    return _database.transaction(() async {
      final customRows =
          await (_database.selectOnly(_database.songs)
                ..addColumns([_database.songs.id])
                ..where(_database.songs.source.equals('custom')))
              .get();
      final customIds = customRows
          .map((row) => row.read(_database.songs.id))
          .whereType<String>()
          .toSet();
      final safeSongs = snapshot.songs
          .where((song) => !customIds.contains(song.id))
          .toList(growable: false);

      await (_database.update(
        _database.songs,
      )..where((row) => row.source.equals('server'))).write(
        SongsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(snapshot.manifest.generatedAt),
        ),
      );

      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.songs,
          safeSongs
              .map(
                (song) => SongsCompanion.insert(
                  id: song.id,
                  title: song.title,
                  englishTitle: Value(song.englishTitle),
                  body: song.body,
                  englishBody: Value(song.englishBody),
                  author: Value(song.author),
                  maleVideoUrl: Value(song.maleVideoUrl),
                  femaleVideoUrl: Value(song.femaleVideoUrl),
                  source: const Value('server'),
                  createdAt: snapshot.manifest.generatedAt,
                  updatedAt: snapshot.manifest.generatedAt,
                  isDeleted: const Value(false),
                ),
              )
              .toList(growable: false),
        );
      });

      await _writeMetadata(
        catalogueVersionKey,
        snapshot.manifest.catalogueVersion,
        now,
      );
      await _writeMetadata(catalogueHashKey, snapshot.manifest.sha256, now);
      await _writeMetadata(lastSuccessfulSyncKey, now.toIso8601String(), now);

      return CatalogueApplyResult(
        activeSongCount: safeSongs.length,
        skippedCustomConflicts: snapshot.songs.length - safeSongs.length,
      );
    });
  }

  Future<String?> _readValue(String key) async {
    final row = await (_database.select(
      _database.appMetadata,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeMetadata(String key, Object value, DateTime now) {
    return _database
        .into(_database.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: key,
            value: value.toString(),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
