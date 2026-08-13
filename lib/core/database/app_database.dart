import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get englishTitle => text().nullable()();
  TextColumn get body => text()();
  TextColumn get englishBody => text().nullable()();
  TextColumn get author => text().nullable()();

  // Internal ownership and synchronization fields are not part of the song
  // editing form, but protect user-created songs during catalogue refreshes.
  TextColumn get source => text().withDefault(const Constant('server'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Songs, AppMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'praise'));

  @override
  int get schemaVersion => 1;

  Stream<List<Song>> watchSongs({String search = ''}) {
    final query = select(songs)
      ..where((row) {
        final active = row.isDeleted.equals(false);
        final term = search.trim().toLowerCase();
        if (term.isEmpty) return active;

        return active &
            (row.title.lower().contains(term) |
                row.englishTitle.lower().contains(term) |
                row.author.lower().contains(term));
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.title),
        (row) => OrderingTerm.asc(row.englishTitle),
      ]);

    return query.watch();
  }

  Stream<Song?> watchSong(String id) {
    return (select(songs)
          ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
        .watchSingleOrNull();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError(
    'databaseProvider must be overridden at application startup',
  );
});
