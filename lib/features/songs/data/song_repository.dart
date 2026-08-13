import '../../../core/database/app_database.dart';

abstract interface class SongRepository {
  Stream<List<Song>> watchSongs({String search});

  Stream<Song?> watchSong(String id);
}

class DriftSongRepository implements SongRepository {
  const DriftSongRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Song>> watchSongs({String search = ''}) {
    return _database.watchSongs(search: search);
  }

  @override
  Stream<Song?> watchSong(String id) => _database.watchSong(id);
}
