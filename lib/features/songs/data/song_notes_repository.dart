import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

abstract interface class SongNotesRepository {
  Stream<SongNote?> watchNote(String songId);

  Future<void> saveNote(String songId, String content);

  Future<void> deleteNote(String songId);
}

class DriftSongNotesRepository implements SongNotesRepository {
  const DriftSongNotesRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<SongNote?> watchNote(String songId) {
    return (_database.select(
      _database.songNotes,
    )..where((row) => row.songId.equals(songId))).watchSingleOrNull();
  }

  @override
  Future<void> saveNote(String songId, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      await deleteNote(songId);
      return;
    }

    final existing = await (_database.select(
      _database.songNotes,
    )..where((row) => row.songId.equals(songId))).getSingleOrNull();
    final now = DateTime.now().toUtc();

    if (existing == null) {
      await _database
          .into(_database.songNotes)
          .insert(
            SongNotesCompanion.insert(
              songId: songId,
              content: trimmed,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }

    await (_database.update(
      _database.songNotes,
    )..where((row) => row.songId.equals(songId))).write(
      SongNotesCompanion(content: Value(trimmed), updatedAt: Value(now)),
    );
  }

  @override
  Future<void> deleteNote(String songId) async {
    await (_database.delete(
      _database.songNotes,
    )..where((row) => row.songId.equals(songId))).go();
  }
}
