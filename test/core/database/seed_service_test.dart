import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/core/database/seed_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('bundled catalogue is seeded exactly once', () async {
    final bundle = _StringAssetBundle('''
      [
        {
          "id": "one",
          "title": "మొదటి పాట",
          "englishTitle": "First Song",
          "body": "మొదటి గీతము",
          "englishBody": "First body",
          "author": "Author One",
          "maleVideoUrl": "https://www.youtube.com/watch?v=male1234567",
          "femaleVideoUrl": "https://youtu.be/female12345"
        },
        {
          "id": "two",
          "title": "రెండవ పాట",
          "body": "రెండవ గీతము"
        }
      ]
    ''');
    final seedService = SeedService(database, assetBundle: bundle);

    await seedService.seedIfNeeded();
    await seedService.seedIfNeeded();

    final songs = await database.select(database.songs).get();
    final metadata = await database.select(database.appMetadata).get();

    expect(songs, hasLength(2));
    expect(metadata, hasLength(1));
    expect(songs.map((song) => song.id), containsAll(['one', 'two']));
    expect(
      songs.firstWhere((song) => song.id == 'one').maleVideoUrl,
      'https://www.youtube.com/watch?v=male1234567',
    );
  });

  test(
    'app catalogue imports every bundled song and preserves existing data',
    () async {
      final now = DateTime.utc(2026, 8, 13);
      await database.batch((batch) {
        batch.insertAll(database.songs, [
          SongsCompanion.insert(
            id: 'old-server-song',
            title: 'Old server song',
            body: 'Old body',
            createdAt: now,
            updatedAt: now,
          ),
          SongsCompanion.insert(
            id: 'custom-song',
            title: 'Custom song',
            body: 'Custom body',
            source: const Value('custom'),
            createdAt: now,
            updatedAt: now,
          ),
        ]);
      });
      final json = await File('assets/data/songs.json').readAsString();
      final bundledSongs = jsonDecode(json) as List<Object?>;

      expect(bundledSongs.length, greaterThanOrEqualTo(1375));

      await SeedService(
        database,
        assetBundle: _StringAssetBundle(json),
      ).seedIfNeeded();

      final songs = await database.select(database.songs).get();
      final serverSongs = songs.where((song) => song.source == 'server');

      expect(serverSongs, hasLength(bundledSongs.length + 1));
      expect(songs.map((song) => song.id), contains('custom-song'));
      expect(songs.map((song) => song.id), contains('old-server-song'));
    },
  );

  test('new seed version upgrades an existing installation safely', () async {
    final now = DateTime.utc(2026, 8, 13);
    final json = await File('assets/data/songs.json').readAsString();
    final bundledSongs = jsonDecode(json) as List<Object?>;
    final firstSong = bundledSongs.first as Map<String, Object?>;
    final firstSongId = firstSong['id']! as String;

    await database.batch((batch) {
      batch.insertAll(database.songs, [
        SongsCompanion.insert(
          id: firstSongId,
          title: 'Outdated bundled title',
          body: 'Outdated bundled body',
          createdAt: now,
          updatedAt: now,
        ),
        SongsCompanion.insert(
          id: 'custom-song',
          title: 'Custom song',
          body: 'Custom body',
          source: const Value('custom'),
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      batch.insert(
        database.appMetadata,
        AppMetadataCompanion.insert(
          key: 'bundled_song_catalogue_version',
          value: '3',
          updatedAt: now,
        ),
      );
    });

    await SeedService(
      database,
      assetBundle: _StringAssetBundle(json),
    ).seedIfNeeded();

    final songs = await database.select(database.songs).get();
    final marker =
        await (database.select(
              database.appMetadata,
            )..where((row) => row.key.equals('bundled_song_catalogue_version')))
            .getSingle();
    final upgradedSong = await (database.select(
      database.songs,
    )..where((row) => row.id.equals(firstSongId))).getSingle();

    expect(
      songs.where((song) => song.source == 'server'),
      hasLength(bundledSongs.length),
    );
    expect(marker.value, '5');
    expect(upgradedSong.title, firstSong['title']);
    expect(upgradedSong.body, firstSong['body']);
    expect(songs.map((song) => song.id), contains('custom-song'));
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
