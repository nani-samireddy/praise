import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'upgrades the installed version 1 database without losing songs',
    () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
      CREATE TABLE songs (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        english_title TEXT NULL,
        body TEXT NOT NULL,
        english_body TEXT NULL,
        author TEXT NULL,
        source TEXT NOT NULL DEFAULT 'server',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE app_metadata (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      INSERT INTO songs (
        id, title, body, source, created_at, updated_at, is_deleted
      ) VALUES (
        'existing', 'Existing song', 'Existing body', 'server', 0, 0, 0
      );
      PRAGMA user_version = 1;
    ''');
      final database = AppDatabase(NativeDatabase.opened(sqlite));
      addTearDown(database.close);

      final songs = await database.select(database.songs).get();
      expect(songs, hasLength(1));
      expect(songs.single.imagePath, isNull);
      expect(await database.select(database.favorites).get(), isEmpty);
      expect(await database.select(database.collections).get(), isEmpty);
      expect(await database.select(database.collectionSongs).get(), isEmpty);
    },
  );
}
