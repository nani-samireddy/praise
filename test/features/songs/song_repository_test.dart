import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_repository.dart';

void main() {
  late AppDatabase database;
  late SongRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftSongRepository(database);
    final now = DateTime.utc(2026, 8, 13);

    await database.batch((batch) {
      batch.insertAll(database.songs, [
        SongsCompanion.insert(
          id: 'grace',
          title: 'అద్భుత కృప',
          englishTitle: const Value('Amazing Grace'),
          body: 'గీతము',
          author: const Value('John Newton'),
          createdAt: now,
          updatedAt: now,
        ),
        SongsCompanion.insert(
          id: 'holy',
          title: 'పరిశుద్ధుడు',
          englishTitle: const Value('Holy, Holy, Holy'),
          body: 'మరొక గీతము',
          author: const Value('Reginald Heber'),
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    });
  });

  tearDown(() async {
    await database.close();
  });

  test('searches primary title, English title, and author locally', () async {
    final primaryTitle = await repository.watchSongs(search: 'అద్భుత').first;
    final englishTitle = await repository.watchSongs(search: 'holy').first;
    final author = await repository.watchSongs(search: 'newton').first;

    expect(primaryTitle.single.id, 'grace');
    expect(englishTitle.single.id, 'holy');
    expect(author.single.id, 'grace');
  });

  test('does not return deleted songs', () async {
    await (database.update(database.songs)
          ..where((row) => row.id.equals('grace')))
        .write(const SongsCompanion(isDeleted: Value(true)));

    final songs = await repository.watchSongs().first;

    expect(songs.map((song) => song.id), isNot(contains('grace')));
    expect(songs.map((song) => song.id), contains('holy'));
  });
}
