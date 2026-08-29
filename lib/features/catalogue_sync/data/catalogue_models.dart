import 'dart:convert';

class CatalogueManifest {
  const CatalogueManifest({
    required this.schemaVersion,
    required this.catalogueVersion,
    required this.generatedAt,
    required this.songCount,
    required this.sha256,
    required this.catalogueUrl,
  });

  factory CatalogueManifest.fromJson(Object? value) {
    final json = _object(value, 'Catalogue manifest');
    final schemaVersion = _integer(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw CatalogueValidationException(
        'Unsupported catalogue schema version $schemaVersion.',
      );
    }

    final catalogueVersion = _integer(json, 'catalogVersion');
    if (catalogueVersion < 1) {
      throw const CatalogueValidationException(
        'Catalogue version must be at least 1.',
      );
    }

    final songCount = _integer(json, 'songCount');
    if (songCount < 0) {
      throw const CatalogueValidationException(
        'Catalogue song count cannot be negative.',
      );
    }

    final sha256 = _string(json, 'sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const CatalogueValidationException(
        'Catalogue checksum must be a SHA-256 value.',
      );
    }

    final generatedAtValue = _string(json, 'generatedAt');
    final generatedAt = DateTime.tryParse(generatedAtValue);
    if (generatedAt == null) {
      throw const CatalogueValidationException(
        'Catalogue generatedAt must be an ISO-8601 timestamp.',
      );
    }

    final catalogueUrl = _string(json, 'catalogUrl');
    final parsedUrl = Uri.tryParse(catalogueUrl);
    if (parsedUrl == null || catalogueUrl.contains('\\')) {
      throw const CatalogueValidationException('Catalogue URL is invalid.');
    }

    return CatalogueManifest(
      schemaVersion: schemaVersion,
      catalogueVersion: catalogueVersion,
      generatedAt: generatedAt.toUtc(),
      songCount: songCount,
      sha256: sha256,
      catalogueUrl: catalogueUrl,
    );
  }

  final int schemaVersion;
  final int catalogueVersion;
  final DateTime generatedAt;
  final int songCount;
  final String sha256;
  final String catalogueUrl;
}

class CatalogueSong {
  const CatalogueSong({
    required this.id,
    required this.title,
    required this.body,
    this.englishTitle,
    this.englishBody,
    this.author,
    this.maleVideoUrl,
    this.femaleVideoUrl,
  });

  factory CatalogueSong.fromJson(Object? value) {
    final json = _object(value, 'Catalogue song');
    return CatalogueSong(
      id: _string(json, 'id'),
      title: _string(json, 'title'),
      body: _string(json, 'body'),
      englishTitle: _optionalString(json, 'englishTitle'),
      englishBody: _optionalString(json, 'englishBody'),
      author: _optionalString(json, 'author'),
      maleVideoUrl: _optionalYoutubeUrl(json, 'maleVideoUrl'),
      femaleVideoUrl: _optionalYoutubeUrl(json, 'femaleVideoUrl'),
    );
  }

  final String id;
  final String title;
  final String? englishTitle;
  final String body;
  final String? englishBody;
  final String? author;
  final String? maleVideoUrl;
  final String? femaleVideoUrl;
}

class CatalogueSnapshot {
  const CatalogueSnapshot({required this.manifest, required this.songs});

  factory CatalogueSnapshot.fromBytes({
    required CatalogueManifest manifest,
    required List<int> bytes,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw CatalogueValidationException(
        'Catalogue is not valid UTF-8 JSON.',
        error,
      );
    }
    if (decoded is! List<Object?>) {
      throw const CatalogueValidationException(
        'Catalogue root must be a JSON array.',
      );
    }

    final songs = decoded.map(CatalogueSong.fromJson).toList(growable: false);
    if (songs.length != manifest.songCount) {
      throw CatalogueValidationException(
        'Manifest expected ${manifest.songCount} songs but received '
        '${songs.length}.',
      );
    }
    final ids = <String>{};
    for (final song in songs) {
      if (!ids.add(song.id)) {
        throw CatalogueValidationException(
          'Catalogue contains duplicate song ID "${song.id}".',
        );
      }
    }
    return CatalogueSnapshot(manifest: manifest, songs: songs);
  }

  final CatalogueManifest manifest;
  final List<CatalogueSong> songs;
}

class CatalogueValidationException implements Exception {
  const CatalogueValidationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw CatalogueValidationException('$name must be a JSON object.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw CatalogueValidationException('$key must be an integer.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw CatalogueValidationException('$key must be non-empty text.');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw CatalogueValidationException('$key must be text or null.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _optionalYoutubeUrl(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase() ?? '';
  final isYoutube =
      host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');
  if (uri == null || !uri.hasScheme || !isYoutube) {
    throw CatalogueValidationException('$key must be a YouTube URL.');
  }
  return value;
}
