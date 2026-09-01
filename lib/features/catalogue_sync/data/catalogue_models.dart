import 'dart:convert';

class CatalogueManifest {
  const CatalogueManifest({
    required this.schemaVersion,
    required this.catalogueVersion,
    required this.generatedAt,
    required this.songCount,
    required this.sha256,
    required this.catalogueUrl,
    this.deltaFromVersion,
    this.deltaSha256,
    this.deltaUrl,
    this.deltas = const [],
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

    final deltaFromVersion = _optionalInteger(json, 'deltaFromVersion');
    final deltaSha256 = _optionalSha256(json, 'deltaSha256');
    final deltaUrl = _optionalString(json, 'deltaUrl');
    if ((deltaFromVersion == null) != (deltaSha256 == null) ||
        (deltaFromVersion == null) != (deltaUrl == null)) {
      throw const CatalogueValidationException(
        'Catalogue delta fields must be provided together.',
      );
    }
    if (deltaFromVersion != null) {
      if (deltaFromVersion < 1 || deltaFromVersion >= catalogueVersion) {
        throw const CatalogueValidationException(
          'Catalogue deltaFromVersion is invalid.',
        );
      }
      final parsedDeltaUrl = Uri.tryParse(deltaUrl!);
      if (parsedDeltaUrl == null || deltaUrl.contains('\\')) {
        throw const CatalogueValidationException(
          'Catalogue delta URL is invalid.',
        );
      }
    }
    final deltas =
        _optionalList(
          json,
          'deltas',
        )?.map(CatalogueDeltaReference.fromJson).toList(growable: false) ??
        const <CatalogueDeltaReference>[];
    final deltaKeys = <String>{};
    for (final delta in deltas) {
      if (delta.fromVersion < 1 ||
          delta.fromVersion >= delta.toVersion ||
          delta.toVersion > catalogueVersion) {
        throw const CatalogueValidationException(
          'Catalogue delta reference version is invalid.',
        );
      }
      if (!deltaKeys.add('${delta.fromVersion}:${delta.toVersion}')) {
        throw const CatalogueValidationException(
          'Catalogue delta references contain duplicates.',
        );
      }
    }

    return CatalogueManifest(
      schemaVersion: schemaVersion,
      catalogueVersion: catalogueVersion,
      generatedAt: generatedAt.toUtc(),
      songCount: songCount,
      sha256: sha256,
      catalogueUrl: catalogueUrl,
      deltaFromVersion: deltaFromVersion,
      deltaSha256: deltaSha256,
      deltaUrl: deltaUrl,
      deltas: deltas,
    );
  }

  final int schemaVersion;
  final int catalogueVersion;
  final DateTime generatedAt;
  final int songCount;
  final String sha256;
  final String catalogueUrl;
  final int? deltaFromVersion;
  final String? deltaSha256;
  final String? deltaUrl;
  final List<CatalogueDeltaReference> deltas;

  bool hasDeltaFrom(int localVersion) =>
      deltaFromVersion == localVersion &&
      deltaSha256 != null &&
      deltaUrl != null;

  List<CatalogueDeltaReference>? deltaChainFrom(int localVersion) {
    final references = <CatalogueDeltaReference>[
      ...deltas,
      if (deltaFromVersion != null && deltaSha256 != null && deltaUrl != null)
        CatalogueDeltaReference(
          fromVersion: deltaFromVersion!,
          toVersion: catalogueVersion,
          sha256: deltaSha256!,
          url: deltaUrl!,
        ),
    ];
    final byFrom = <int, CatalogueDeltaReference>{};
    for (final reference in references) {
      byFrom.putIfAbsent(reference.fromVersion, () => reference);
    }

    final chain = <CatalogueDeltaReference>[];
    var currentVersion = localVersion;
    while (currentVersion < catalogueVersion) {
      final reference = byFrom[currentVersion];
      if (reference == null || reference.toVersion <= currentVersion) {
        return null;
      }
      chain.add(reference);
      currentVersion = reference.toVersion;
    }
    return currentVersion == catalogueVersion ? chain : null;
  }
}

class CatalogueDeltaReference {
  const CatalogueDeltaReference({
    required this.fromVersion,
    required this.toVersion,
    required this.sha256,
    required this.url,
  });

  factory CatalogueDeltaReference.fromJson(Object? value) {
    final json = _object(value, 'Catalogue delta reference');
    final sha256 = _string(json, 'sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const CatalogueValidationException(
        'Catalogue delta reference checksum must be a SHA-256 value.',
      );
    }
    final url = _string(json, 'url');
    final parsedUrl = Uri.tryParse(url);
    if (parsedUrl == null || url.contains('\\')) {
      throw const CatalogueValidationException(
        'Catalogue delta reference URL is invalid.',
      );
    }
    return CatalogueDeltaReference(
      fromVersion: _integer(json, 'fromVersion'),
      toVersion: _integer(json, 'toVersion'),
      sha256: sha256,
      url: url,
    );
  }

  final int fromVersion;
  final int toVersion;
  final String sha256;
  final String url;
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

class CatalogueDelta {
  const CatalogueDelta({
    required this.fromVersion,
    required this.toVersion,
    required this.upserts,
    required this.deletes,
  });

  factory CatalogueDelta.fromBytes({
    required CatalogueDeltaReference reference,
    required List<int> bytes,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw CatalogueValidationException(
        'Catalogue delta is not valid UTF-8 JSON.',
        error,
      );
    }
    final json = _object(decoded, 'Catalogue delta');
    final fromVersion = _integer(json, 'fromVersion');
    final toVersion = _integer(json, 'toVersion');
    if (fromVersion != reference.fromVersion ||
        toVersion != reference.toVersion) {
      throw const CatalogueValidationException(
        'Catalogue delta version does not match the reference.',
      );
    }

    final upserts = _list(
      json,
      'upserts',
    ).map(CatalogueSong.fromJson).toList(growable: false);
    final deletes = _list(json, 'deletes')
        .map((value) {
          if (value is! String || value.trim().isEmpty) {
            throw const CatalogueValidationException(
              'Catalogue delta delete IDs must be non-empty text.',
            );
          }
          return value.trim();
        })
        .toList(growable: false);

    final ids = <String>{};
    for (final song in upserts) {
      if (!ids.add(song.id)) {
        throw CatalogueValidationException(
          'Catalogue delta contains duplicate song ID "${song.id}".',
        );
      }
    }
    for (final id in deletes) {
      if (!ids.add(id)) {
        throw CatalogueValidationException(
          'Catalogue delta both upserts and deletes song ID "$id".',
        );
      }
    }

    return CatalogueDelta(
      fromVersion: fromVersion,
      toVersion: toVersion,
      upserts: upserts,
      deletes: deletes,
    );
  }

  final int fromVersion;
  final int toVersion;
  final List<CatalogueSong> upserts;
  final List<String> deletes;
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

int? _optionalInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
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

String? _optionalSha256(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final lower = value.toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(lower)) {
    throw CatalogueValidationException('$key must be a SHA-256 value.');
  }
  return lower;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw CatalogueValidationException('$key must be a JSON array.');
  }
  return value;
}

List<Object?>? _optionalList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List<Object?>) {
    throw CatalogueValidationException('$key must be a JSON array.');
  }
  return value;
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
