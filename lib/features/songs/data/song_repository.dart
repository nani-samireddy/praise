import '../../../core/database/app_database.dart';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class SongInput {
  const SongInput({
    required this.title,
    required this.body,
    this.englishTitle,
    this.englishBody,
    this.author,
  });

  final String title;
  final String? englishTitle;
  final String body;
  final String? englishBody;
  final String? author;
}

abstract interface class SongRepository {
  Stream<List<Song>> watchSongs({String search});

  Stream<Song?> watchSong(String id);

  Future<String> createCustomSong(SongInput input);

  Future<void> updateCustomSong(String id, SongInput input);

  Future<void> deleteCustomSong(String id);
}

class DriftSongRepository implements SongRepository {
  DriftSongRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  static const mySongsCollectionId = 'system-my-songs';

  @override
  Stream<List<Song>> watchSongs({String search = ''}) {
    return _database.watchSongs(search: search);
  }

  @override
  Stream<Song?> watchSong(String id) => _database.watchSong(id);

  @override
  Future<String> createCustomSong(SongInput input) async {
    final now = DateTime.now().toUtc();
    final id = 'custom-${_uuid.v4()}';
    await _database.transaction(() async {
      await _database
          .into(_database.songs)
          .insert(
            SongsCompanion.insert(
              id: id,
              title: _required(input.title, 'Title'),
              englishTitle: Value(_optional(input.englishTitle)),
              body: _required(input.body, 'Body'),
              englishBody: Value(_optional(input.englishBody)),
              author: Value(_optional(input.author)),
              source: const Value('custom'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database
          .into(_database.collections)
          .insert(
            CollectionsCompanion.insert(
              id: mySongsCollectionId,
              name: 'My Songs',
              isSystem: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final maxOrder = _database.collectionSongs.sortOrder.max();
      final nextOrderQuery = _database.selectOnly(_database.collectionSongs)
        ..addColumns([maxOrder])
        ..where(
          _database.collectionSongs.collectionId.equals(mySongsCollectionId),
        );
      final currentMax =
          await nextOrderQuery.map((row) => row.read(maxOrder)).getSingle() ??
          -1;
      await _database
          .into(_database.collectionSongs)
          .insert(
            CollectionSongsCompanion.insert(
              collectionId: mySongsCollectionId,
              songId: id,
              sortOrder: currentMax + 1,
              createdAt: now,
            ),
          );
    });
    return id;
  }

  @override
  Future<void> updateCustomSong(String id, SongInput input) async {
    final affected =
        await (_database.update(_database.songs)
              ..where((row) => row.id.equals(id) & row.source.equals('custom')))
            .write(
              SongsCompanion(
                title: Value(_required(input.title, 'Title')),
                englishTitle: Value(_optional(input.englishTitle)),
                body: Value(_required(input.body, 'Body')),
                englishBody: Value(_optional(input.englishBody)),
                author: Value(_optional(input.author)),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (affected != 1) {
      throw StateError('Only existing custom songs can be edited.');
    }
  }

  @override
  Future<void> deleteCustomSong(String id) async {
    final affected = await (_database.delete(
      _database.songs,
    )..where((row) => row.id.equals(id) & row.source.equals('custom'))).go();
    if (affected != 1) {
      throw StateError('Only existing custom songs can be deleted.');
    }
  }

  static String _required(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError('$fieldName is required.');
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
