import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/favorites/data/favorites_repository.dart';

void main() {
  late AppDatabase database;
  late FavoritesRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftFavoritesRepository(database);
    final now = DateTime.utc(2026, 8, 13);
    await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            id: 'song',
            title: 'పాట',
            body: 'గీతము',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('stores and removes favorite state', () async {
    await repository.setFavorite('song', isFavorite: true);

    expect(await repository.watchIsFavorite('song').first, isTrue);
    expect((await repository.watchFavorites().first).single.id, 'song');

    final secondRepository = DriftFavoritesRepository(database);
    expect(await secondRepository.watchIsFavorite('song').first, isTrue);

    await repository.setFavorite('song', isFavorite: false);
    expect(await repository.watchIsFavorite('song').first, isFalse);
    expect(await repository.watchFavorites().first, isEmpty);
  });
}
