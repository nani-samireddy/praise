import '../../../core/database/app_database.dart';
import '../../../core/text/telugu_transliterator.dart';
import '../../custom_songs/data/custom_song_image_store.dart';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class SongInput {
  const SongInput({
    required this.title,
    required this.body,
    this.englishTitle,
    this.englishBody,
    this.author,
    this.newImagePath,
    this.maleVideoUrl,
    this.femaleVideoUrl,
    this.removeImage = false,
  });

  final String title;
  final String? englishTitle;
  final String body;
  final String? englishBody;
  final String? author;
  final String? newImagePath;
  final String? maleVideoUrl;
  final String? femaleVideoUrl;
  final bool removeImage;
}

abstract interface class SongRepository {
  Stream<List<Song>> watchSongs({String search});

  Stream<Song?> watchSong(String id);

  Future<String> createCustomSong(SongInput input);

  Future<void> updateCustomSong(String id, SongInput input);

  Future<void> deleteCustomSong(String id);
}

class DriftSongRepository implements SongRepository {
  DriftSongRepository(this._database, {Uuid? uuid, this.imageStore})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;
  final CustomSongImageStore? imageStore;

  static const mySongsCollectionId = 'system-my-songs';

  @override
  Stream<List<Song>> watchSongs({String search = ''}) {
    return _database.watchSongs(search: search);
  }

  @override
  Stream<Song?> watchSong(String id) => _database.watchSong(id);

  @override
  Future<String> createCustomSong(SongInput input) async {
    final now = DateTime.now().toUtc();
    final id = 'custom-${_uuid.v4()}';
    final title = _required(input.title, 'Title');
    final englishTitle = _englishTitle(input.englishTitle, title);
    final imagePath = await _saveImage(input.newImagePath);
    late final String body;
    try {
      body = _bodyOrImage(input.body, imagePath);
    } catch (_) {
      await _deleteImage(imagePath);
      rethrow;
    }
    try {
      await _database.transaction(() async {
        await _database
            .into(_database.songs)
            .insert(
              SongsCompanion.insert(
                id: id,
                title: title,
                englishTitle: Value(englishTitle),
                body: body,
                englishBody: Value(_optional(input.englishBody)),
                author: Value(_optional(input.author)),
                imagePath: Value(imagePath),
                maleVideoUrl: Value(_optionalVideoUrl(input.maleVideoUrl)),
                femaleVideoUrl: Value(_optionalVideoUrl(input.femaleVideoUrl)),
                source: const Value('custom'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _database
            .into(_database.collections)
            .insert(
              CollectionsCompanion.insert(
                id: mySongsCollectionId,
                name: 'My Songs',
                isSystem: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        final maxOrder = _database.collectionSongs.sortOrder.max();
        final nextOrderQuery = _database.selectOnly(_database.collectionSongs)
          ..addColumns([maxOrder])
          ..where(
            _database.collectionSongs.collectionId.equals(mySongsCollectionId),
          );
        final currentMax =
            await nextOrderQuery.map((row) => row.read(maxOrder)).getSingle() ??
            -1;
        await _database
            .into(_database.collectionSongs)
            .insert(
              CollectionSongsCompanion.insert(
                collectionId: mySongsCollectionId,
                songId: id,
                sortOrder: currentMax + 1,
                createdAt: now,
              ),
            );
      });
    } catch (_) {
      await _deleteImage(imagePath);
      rethrow;
    }
    return id;
  }

  @override
  Future<void> updateCustomSong(String id, SongInput input) async {
    final existing =
        await (_database.select(_database.songs)
              ..where((row) => row.id.equals(id) & row.source.equals('custom')))
            .getSingleOrNull();
    if (existing == null) {
      throw StateError('Only existing custom songs can be edited.');
    }
    final title = _required(input.title, 'Title');
    final replacementImagePath = await _saveImage(input.newImagePath);
    final imagePath =
        replacementImagePath ?? (input.removeImage ? null : existing.imagePath);
    late final String body;
    try {
      body = _bodyOrImage(input.body, imagePath);
    } catch (_) {
      await _deleteImage(replacementImagePath);
      rethrow;
    }
    int affected;
    try {
      affected =
          await (_database.update(_database.songs)..where(
                (row) => row.id.equals(id) & row.source.equals('custom'),
              ))
              .write(
                SongsCompanion(
                  title: Value(title),
                  englishTitle: Value(_englishTitle(input.englishTitle, title)),
                  body: Value(body),
                  englishBody: Value(_optional(input.englishBody)),
                  author: Value(_optional(input.author)),
                  imagePath: Value(imagePath),
                  maleVideoUrl: Value(_optionalVideoUrl(input.maleVideoUrl)),
                  femaleVideoUrl: Value(
                    _optionalVideoUrl(input.femaleVideoUrl),
                  ),
                  updatedAt: Value(DateTime.now().toUtc()),
                ),
              );
    } catch (_) {
      await _deleteImage(replacementImagePath);
      rethrow;
    }
    if (affected != 1) {
      await _deleteImage(replacementImagePath);
      throw StateError('Only existing custom songs can be edited.');
    }
    if (existing.imagePath != imagePath) {
      await _deleteImage(existing.imagePath);
    }
  }

  @override
  Future<void> deleteCustomSong(String id) async {
    final existing =
        await (_database.select(_database.songs)
              ..where((row) => row.id.equals(id) & row.source.equals('custom')))
            .getSingleOrNull();
    if (existing == null) {
      throw StateError('Only existing custom songs can be deleted.');
    }
    final affected = await (_database.delete(
      _database.songs,
    )..where((row) => row.id.equals(id) & row.source.equals('custom'))).go();
    if (affected != 1) {
      throw StateError('Only existing custom songs can be deleted.');
    }
    await _deleteImage(existing.imagePath);
  }

  static String _required(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError('$fieldName is required.');
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _optionalVideoUrl(String? value) {
    final trimmed = _optional(value);
    if (trimmed == null) return null;
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.toLowerCase() ?? '';
    final isYoutube =
        host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
    if (uri == null || !uri.hasScheme || !isYoutube) {
      throw ArgumentError('Use a valid YouTube URL.');
    }
    return trimmed;
  }

  static String _englishTitle(String? value, String title) {
    return _optional(value) ?? transliterateTeluguTitle(title);
  }

  static String _bodyOrImage(String body, String? imagePath) {
    final trimmed = body.trim();
    if (trimmed.isEmpty && imagePath == null) {
      throw ArgumentError('Body or song photo is required.');
    }
    return trimmed;
  }

  Future<String?> _saveImage(String? sourcePath) async {
    final value = _optional(sourcePath);
    if (value == null) return null;
    final store = imageStore;
    if (store == null) {
      throw StateError('Song photo storage is unavailable.');
    }
    return store.save(value);
  }

  Future<void> _deleteImage(String? storedPath) async {
    if (storedPath == null) return;
    try {
      await imageStore?.delete(storedPath);
    } catch (_) {
      // The database is authoritative; a cleanup failure must not undo a save
      // or make a successfully deleted song appear to remain.
    }
  }
}
