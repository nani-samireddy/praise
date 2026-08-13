import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class CollectionSummary {
  const CollectionSummary({required this.collection, required this.songCount});

  final SongCollection collection;
  final int songCount;
}

abstract interface class CollectionsRepository {
  Stream<List<CollectionSummary>> watchCollections();

  Stream<SongCollection?> watchCollection(String id);

  Stream<List<Song>> watchCollectionSongs(String id);

  Stream<Set<String>> watchCollectionIdsForSong(String songId);

  Future<String> createCollection(String name);

  Future<void> renameCollection(String id, String name);

  Future<void> deleteCollection(String id);

  Future<void> addSong(String collectionId, String songId);

  Future<void> removeSong(String collectionId, String songId);

  Future<void> reorderSongs(String collectionId, List<String> songIds);
}

class DriftCollectionsRepository implements CollectionsRepository {
  DriftCollectionsRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Stream<List<CollectionSummary>> watchCollections() {
    final count = _database.collectionSongs.songId.count();
    final query =
        _database.select(_database.collections).join([
            leftOuterJoin(
              _database.collectionSongs,
              _database.collectionSongs.collectionId.equalsExp(
                _database.collections.id,
              ),
            ),
          ])
          ..addColumns([count])
          ..groupBy([_database.collections.id])
          ..orderBy([OrderingTerm.asc(_database.collections.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CollectionSummary(
              collection: row.readTable(_database.collections),
              songCount: row.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  @override
  Stream<SongCollection?> watchCollection(String id) {
    return (_database.select(
      _database.collections,
    )..where((row) => row.id.equals(id))).watchSingleOrNull();
  }

  @override
  Stream<List<Song>> watchCollectionSongs(String id) {
    final query =
        _database.select(_database.collectionSongs).join([
            innerJoin(
              _database.songs,
              _database.songs.id.equalsExp(_database.collectionSongs.songId),
            ),
          ])
          ..where(
            _database.collectionSongs.collectionId.equals(id) &
                _database.songs.isDeleted.equals(false),
          )
          ..orderBy([OrderingTerm.asc(_database.collectionSongs.sortOrder)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.songs)).toList(),
    );
  }

  @override
  Stream<Set<String>> watchCollectionIdsForSong(String songId) {
    final query =
        _database.select(_database.collectionSongs).join([
          innerJoin(
            _database.collections,
            _database.collections.id.equalsExp(
              _database.collectionSongs.collectionId,
            ),
          ),
        ])..where(
          _database.collectionSongs.songId.equals(songId) &
              _database.collections.isSystem.equals(false),
        );
    return query.watch().map(
      (rows) => rows
          .map((row) => row.readTable(_database.collectionSongs).collectionId)
          .toSet(),
    );
  }

  @override
  Future<String> createCollection(String name) async {
    final now = DateTime.now().toUtc();
    final id = 'list-${_uuid.v4()}';
    await _database
        .into(_database.collections)
        .insert(
          CollectionsCompanion.insert(
            id: id,
            name: _validName(name),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  @override
  Future<void> renameCollection(String id, String name) async {
    final affected =
        await (_database.update(_database.collections)
              ..where((row) => row.id.equals(id) & row.isSystem.equals(false)))
            .write(
              CollectionsCompanion(
                name: Value(_validName(name)),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (affected != 1) throw StateError('This list cannot be renamed.');
  }

  @override
  Future<void> deleteCollection(String id) async {
    final affected = await (_database.delete(
      _database.collections,
    )..where((row) => row.id.equals(id) & row.isSystem.equals(false))).go();
    if (affected != 1) throw StateError('This list cannot be deleted.');
  }

  @override
  Future<void> addSong(String collectionId, String songId) async {
    await _database.transaction(() async {
      await _requireEditableCollection(collectionId);
      final maxOrder = _database.collectionSongs.sortOrder.max();
      final query = _database.selectOnly(_database.collectionSongs)
        ..addColumns([maxOrder])
        ..where(_database.collectionSongs.collectionId.equals(collectionId));
      final currentMax =
          await query.map((row) => row.read(maxOrder)).getSingle() ?? -1;
      await _database
          .into(_database.collectionSongs)
          .insert(
            CollectionSongsCompanion.insert(
              collectionId: collectionId,
              songId: songId,
              sortOrder: currentMax + 1,
              createdAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  @override
  Future<void> removeSong(String collectionId, String songId) async {
    await _database.transaction(() async {
      await _requireEditableCollection(collectionId);
      await (_database.delete(_database.collectionSongs)..where(
            (row) =>
                row.collectionId.equals(collectionId) &
                row.songId.equals(songId),
          ))
          .go();
      await _normalizeOrder(collectionId);
    });
  }

  @override
  Future<void> reorderSongs(String collectionId, List<String> songIds) async {
    await _database.transaction(() async {
      await _requireEditableCollection(collectionId);
      final current = await (_database.select(
        _database.collectionSongs,
      )..where((row) => row.collectionId.equals(collectionId))).get();
      if (current.map((row) => row.songId).toSet().length != songIds.length ||
          !current.map((row) => row.songId).toSet().containsAll(songIds)) {
        throw ArgumentError('The reordered songs do not match this list.');
      }
      for (var index = 0; index < songIds.length; index++) {
        await (_database.update(_database.collectionSongs)..where(
              (row) =>
                  row.collectionId.equals(collectionId) &
                  row.songId.equals(songIds[index]),
            ))
            .write(CollectionSongsCompanion(sortOrder: Value(index)));
      }
    });
  }

  Future<void> _requireEditableCollection(String id) async {
    final collection = await (_database.select(
      _database.collections,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (collection == null || collection.isSystem) {
      throw StateError('This list cannot be changed manually.');
    }
  }

  Future<void> _normalizeOrder(String collectionId) async {
    final rows =
        await (_database.select(_database.collectionSongs)
              ..where((row) => row.collectionId.equals(collectionId))
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].sortOrder == index) continue;
      await (_database.update(_database.collectionSongs)..where(
            (row) =>
                row.collectionId.equals(collectionId) &
                row.songId.equals(rows[index].songId),
          ))
          .write(CollectionSongsCompanion(sortOrder: Value(index)));
    }
  }

  static String _validName(String value) {
    final name = value.trim();
    if (name.isEmpty) throw ArgumentError('List name is required.');
    return name;
  }
}
