import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

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
    this.isScanned = false,
    this.aiEnhanced = false,
    this.aiFallback = false,
  });

  final String title;
  final String englishTitle;
  final String body;
  final String englishBody;
  final String author;
  final String maleVideoUrl;
  final String femaleVideoUrl;
  final String? imagePath;
  final bool detailsExpanded;
  final bool isScanned;
  final bool aiEnhanced;
  final bool aiFallback;

  @override
  bool operator ==(Object other) =>
      other is LocalSongDraft &&
      other.title == title &&
      other.englishTitle == englishTitle &&
      other.body == body &&
      other.englishBody == englishBody &&
      other.author == author &&
      other.maleVideoUrl == maleVideoUrl &&
      other.femaleVideoUrl == femaleVideoUrl &&
      other.imagePath == imagePath &&
      other.detailsExpanded == detailsExpanded &&
      other.isScanned == isScanned &&
      other.aiEnhanced == aiEnhanced &&
      other.aiFallback == aiFallback;

  @override
  int get hashCode => Object.hash(
    title,
    englishTitle,
    body,
    englishBody,
    author,
    maleVideoUrl,
    femaleVideoUrl,
    imagePath,
    detailsExpanded,
    isScanned,
    aiEnhanced,
    aiFallback,
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
    'title': title,
    'englishTitle': englishTitle,
    'body': body,
    'englishBody': englishBody,
    'author': author,
    'maleVideoUrl': maleVideoUrl,
    'femaleVideoUrl': femaleVideoUrl,
    'imagePath': imagePath,
    'detailsExpanded': detailsExpanded,
    'isScanned': isScanned,
    'aiEnhanced': aiEnhanced,
    'aiFallback': aiFallback,
  };

  factory LocalSongDraft.fromJson(Map<Object?, Object?> json) {
    String value(String key) => json[key] is String ? json[key] as String : '';

    return LocalSongDraft(
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
      isScanned: json['isScanned'] == true,
      aiEnhanced: json['aiEnhanced'] == true,
      aiFallback: json['aiFallback'] == true,
    );
  }
}

class LocalSongDraftStore {
  LocalSongDraftStore(this._database);

  static const _metadataKey = 'custom_song_draft';

  final AppDatabase _database;

  Future<LocalSongDraft?> load() async {
    final row = await (_database.select(
      _database.appMetadata,
    )..where((item) => item.key.equals(_metadataKey))).getSingleOrNull();
    if (row == null) return null;

    try {
      final decoded = jsonDecode(row.value);
      if (decoded is! Map) return null;
      return LocalSongDraft.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> save(LocalSongDraft draft) async {
    await _database
        .into(_database.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: _metadataKey,
            value: jsonEncode(draft.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> clear() async {
    await (_database.delete(
      _database.appMetadata,
    )..where((item) => item.key.equals(_metadataKey))).go();
  }
}
