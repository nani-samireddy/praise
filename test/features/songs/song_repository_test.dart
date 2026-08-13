import 'package:drift/drift.dart' hide isNull;
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

  test('creates, updates, and deletes a custom song', () async {
    final id = await repository.createCustomSong(
      const SongInput(
        title: '  నా పాట  ',
        englishTitle: '  My Song  ',
        body: '  నా గీతము  ',
        englishBody: '  My lyrics  ',
        author: '  Local Author  ',
      ),
    );

    var song = await repository.watchSong(id).first;
    expect(song?.source, 'custom');
    expect(song?.title, 'నా పాట');
    expect(song?.author, 'Local Author');
    final mySongs = await database.select(database.collections).get();
    final membership = await database.select(database.collectionSongs).get();
    expect(mySongs.single.name, 'My Songs');
    expect(mySongs.single.isSystem, isTrue);
    expect(membership.single.songId, id);

    await repository.updateCustomSong(
      id,
      const SongInput(title: 'Updated', body: 'Updated body'),
    );
    song = await repository.watchSong(id).first;
    expect(song?.title, 'Updated');
    expect(song?.englishTitle, isNull);

    await repository.deleteCustomSong(id);
    expect(await repository.watchSong(id).first, isNull);
    expect(await database.select(database.collectionSongs).get(), isEmpty);
  });

  test('reuses My Songs and appends each new custom song', () async {
    final firstId = await repository.createCustomSong(
      const SongInput(title: 'First custom', body: 'First body'),
    );
    final secondId = await repository.createCustomSong(
      const SongInput(title: 'Second custom', body: 'Second body'),
    );

    final collections = await database.select(database.collections).get();
    final membership = await (database.select(
      database.collectionSongs,
    )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();

    expect(collections, hasLength(1));
    expect(membership.map((row) => row.songId), [firstId, secondId]);
    expect(membership.map((row) => row.sortOrder), [0, 1]);
  });

  test('does not allow server songs to be edited as custom songs', () async {
    expect(
      () => repository.updateCustomSong(
        'grace',
        const SongInput(title: 'Changed', body: 'Changed body'),
      ),
      throwsStateError,
    );
  });
}
