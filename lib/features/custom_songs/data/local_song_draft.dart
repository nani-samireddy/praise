import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'custom_song_image_store.dart';

class LocalSongDraft {
  const LocalSongDraft({
    required this.title,
    required this.englishTitle,
    required this.body,
    required this.englishBody,
    required this.author,
    required this.maleVideoUrl,
    required this.femaleVideoUrl,
    required this.imagePath,
    required this.detailsExpanded,
    this.baseUpdatedAt,
  });

  final String? baseUpdatedAt;
  final String title;
  final String englishTitle;
  final String body;
  final String englishBody;
  final String author;
  final String maleVideoUrl;
  final String femaleVideoUrl;
  final String? imagePath;
  final bool detailsExpanded;

  @override
  bool operator ==(Object other) =>
      other is LocalSongDraft &&
      other.baseUpdatedAt == baseUpdatedAt &&
      other.title == title &&
      other.englishTitle == englishTitle &&
      other.body == body &&
      other.englishBody == englishBody &&
      other.author == author &&
      other.maleVideoUrl == maleVideoUrl &&
      other.femaleVideoUrl == femaleVideoUrl &&
      other.imagePath == imagePath &&
      other.detailsExpanded == detailsExpanded;

  @override
  int get hashCode => Object.hash(
    baseUpdatedAt,
    title,
    englishTitle,
    body,
    englishBody,
    author,
    maleVideoUrl,
    femaleVideoUrl,
    imagePath,
    detailsExpanded,
  );

  bool get isEmpty =>
      title.trim().isEmpty &&
      englishTitle.trim().isEmpty &&
      body.trim().isEmpty &&
      englishBody.trim().isEmpty &&
      author.trim().isEmpty &&
      maleVideoUrl.trim().isEmpty &&
      femaleVideoUrl.trim().isEmpty &&
      imagePath == null;

  Map<String, Object?> toJson() => {
    'baseUpdatedAt': baseUpdatedAt,
    'title': title,
    'englishTitle': englishTitle,
    'body': body,
    'englishBody': englishBody,
    'author': author,
    'maleVideoUrl': maleVideoUrl,
    'femaleVideoUrl': femaleVideoUrl,
    'imagePath': imagePath,
    'detailsExpanded': detailsExpanded,
  };

  factory LocalSongDraft.fromJson(Map<Object?, Object?> json) {
    String value(String key) => json[key] is String ? json[key] as String : '';

    return LocalSongDraft(
      baseUpdatedAt: json['baseUpdatedAt'] as String?,
      title: value('title'),
      englishTitle: value('englishTitle'),
      body: value('body'),
      englishBody: value('englishBody'),
      author: value('author'),
      maleVideoUrl: value('maleVideoUrl'),
      femaleVideoUrl: value('femaleVideoUrl'),
      imagePath: json['imagePath'] is String
          ? json['imagePath'] as String
          : null,
      detailsExpanded: json['detailsExpanded'] == true,
    );
  }
}

class LocalSongDraftStore {
  LocalSongDraftStore(this._database);

  static const _metadataKey = 'custom_song_draft';

  final AppDatabase _database;

  String _key(String? songId) =>
      songId == null ? _metadataKey : '${_metadataKey}_edit_$songId';

  Future<LocalSongDraft?> load({String? songId}) async {
    final row = await (_database.select(
      _database.appMetadata,
    )..where((item) => item.key.equals(_key(songId)))).getSingleOrNull();
    if (row == null) return null;

    try {
      final decoded = jsonDecode(row.value);
      if (decoded is! Map) return null;
      return LocalSongDraft.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> save(LocalSongDraft draft, {String? songId}) async {
    await _database
        .into(_database.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: _key(songId),
            value: jsonEncode(draft.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> deleteUnreferencedImage(
    String? imagePath, {
    CustomSongImageStore? imageStore,
  }) async {
    if (imagePath == null) return;
    final songs = await (_database.select(
      _database.songs,
    )..where((song) => song.imagePath.equals(imagePath))).get();
    if (songs.isNotEmpty) return;
    final rows = await (_database.select(
      _database.appMetadata,
    )..where((row) => row.key.like('custom_song_draft%'))).get();
    for (final row in rows) {
      try {
        final json = jsonDecode(row.value);
        if (json is Map && json['imagePath'] == imagePath) return;
      } catch (_) {
        // Unknown draft contents must not cause destructive cleanup.
        return;
      }
    }
    await (imageStore ?? LocalCustomSongImageStore()).delete(imagePath);
  }

  Future<void> clear({String? songId}) async {
    await (_database.delete(
      _database.appMetadata,
    )..where((item) => item.key.equals(_key(songId)))).go();
  }
}
