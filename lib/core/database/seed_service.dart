import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import 'app_database.dart';

class SeedService {
  SeedService(this._database, {AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const _assetPath = 'assets/data/songs.json';
  static const _seedVersionKey = 'bundled_song_catalogue_version';
  static const _seedVersion = '3';

  final AppDatabase _database;
  final AssetBundle _assetBundle;

  Future<void> seedIfNeeded() async {
    final marker = await (_database.select(
      _database.appMetadata,
    )..where((row) => row.key.equals(_seedVersionKey))).getSingleOrNull();
    if (marker?.value == _seedVersion) return;

    final rawJson = await _assetBundle.loadString(_assetPath);
    final decoded = jsonDecode(rawJson);
    if (decoded is! List<Object?>) {
      throw const FormatException('The bundled song catalogue must be a list.');
    }

    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final customRows =
          await (_database.selectOnly(_database.songs)
                ..addColumns([_database.songs.id])
                ..where(_database.songs.source.equals('custom')))
              .get();
      final customIds = customRows
          .map((row) => row.read(_database.songs.id))
          .whereType<String>()
          .toSet();
      final songs = <SongsCompanion>[];

      for (final value in decoded) {
        if (value is! Map<String, Object?>) {
          throw const FormatException('Every bundled song must be an object.');
        }

        final id = _requiredString(value, 'id');
        if (customIds.contains(id)) continue;
        final title = _requiredString(value, 'title');
        final body = _requiredString(value, 'body');

        songs.add(
          SongsCompanion.insert(
            id: id,
            title: title,
            englishTitle: Value(_optionalString(value, 'englishTitle')),
            body: body,
            englishBody: Value(_optionalString(value, 'englishBody')),
            author: Value(_optionalString(value, 'author')),
            source: const Value('server'),
            createdAt: now,
            updatedAt: now,
            isDeleted: const Value(false),
          ),
        );
      }

      await _database.batch(
        (batch) => batch.insertAllOnConflictUpdate(_database.songs, songs),
      );

      await _database
          .into(_database.appMetadata)
          .insert(
            AppMetadataCompanion.insert(
              key: _seedVersionKey,
              value: _seedVersion,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Bundled song field "$key" is required.');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Bundled song field "$key" must be text.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
