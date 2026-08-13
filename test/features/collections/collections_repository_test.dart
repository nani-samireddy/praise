import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/collections/data/collections_repository.dart';

void main() {
  late AppDatabase database;
  late CollectionsRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftCollectionsRepository(database);
    final now = DateTime.utc(2026, 8, 13);
    await database.batch((batch) {
      batch.insertAll(database.songs, [
        SongsCompanion.insert(
          id: 'one',
          title: 'One',
          body: 'Body one',
          createdAt: now,
          updatedAt: now,
        ),
        SongsCompanion.insert(
          id: 'two',
          title: 'Two',
          body: 'Body two',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    });
  });

  tearDown(() async {
    await database.close();
  });

  test('creates, renames, populates, reorders, and deletes a list', () async {
    final id = await repository.createCollection('  Sunday Worship  ');
    await repository.addSong(id, 'one');
    await repository.addSong(id, 'one');
    await repository.addSong(id, 'two');

    expect(
      (await repository.watchCollection(id).first)?.name,
      'Sunday Worship',
    );
    expect(
      (await repository.watchCollectionSongs(id).first).map((song) => song.id),
      ['one', 'two'],
    );
    expect(await repository.watchCollectionIdsForSong('one').first, {id});

    await repository.reorderSongs(id, ['two', 'one']);
    expect(
      (await repository.watchCollectionSongs(id).first).map((song) => song.id),
      ['two', 'one'],
    );

    await repository.removeSong(id, 'two');
    await repository.renameCollection(id, 'Prayer Meeting');
    expect(
      (await repository.watchCollection(id).first)?.name,
      'Prayer Meeting',
    );

    await repository.deleteCollection(id);
    expect(await repository.watchCollection(id).first, isNull);
    expect(await database.select(database.collectionSongs).get(), isEmpty);
  });

  test('protects system lists from manual changes', () async {
    final now = DateTime.utc(2026, 8, 13);
    await database
        .into(database.collections)
        .insert(
          CollectionsCompanion.insert(
            id: 'system',
            name: 'My Songs',
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(repository.renameCollection('system', 'Changed'), throwsStateError);
    expect(repository.deleteCollection('system'), throwsStateError);
    expect(repository.addSong('system', 'one'), throwsStateError);
  });
}
