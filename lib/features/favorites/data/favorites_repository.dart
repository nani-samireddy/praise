import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

abstract interface class FavoritesRepository {
  Stream<List<Song>> watchFavorites();

  Stream<bool> watchIsFavorite(String songId);

  Future<void> setFavorite(String songId, {required bool isFavorite});
}

class DriftFavoritesRepository implements FavoritesRepository {
  const DriftFavoritesRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Song>> watchFavorites() {
    final query =
        _database.select(_database.songs).join([
            innerJoin(
              _database.favorites,
              _database.favorites.songId.equalsExp(_database.songs.id),
            ),
          ])
          ..where(_database.songs.isDeleted.equals(false))
          ..orderBy([OrderingTerm.asc(_database.songs.title)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.songs)).toList(),
    );
  }

  @override
  Stream<bool> watchIsFavorite(String songId) {
    return (_database.select(_database.favorites)
          ..where((row) => row.songId.equals(songId)))
        .watchSingleOrNull()
        .map((favorite) => favorite != null);
  }

  @override
  Future<void> setFavorite(String songId, {required bool isFavorite}) async {
    if (isFavorite) {
      await _database
          .into(_database.favorites)
          .insert(
            FavoritesCompanion.insert(
              songId: songId,
              createdAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return;
    }

    await (_database.delete(
      _database.favorites,
    )..where((row) => row.songId.equals(songId))).go();
  }
}
