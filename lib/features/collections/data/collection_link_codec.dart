import 'dart:convert';

import '../../../core/database/app_database.dart';

class SharedCollectionPayload {
  const SharedCollectionPayload({
    required this.name,
    required this.songIds,
    this.duplicateCount = 0,
  });

  final String name;
  final List<String> songIds;
  final int duplicateCount;
}

class CollectionLinkException implements Exception {
  const CollectionLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

const maximumCollectionLinkSongs = 300;
const maximumCollectionLinkLength = 12000;

Uri buildCollectionLink(SongCollection collection, List<Song> songs) {
  final catalogueSongs = songs
      .where((song) => song.source == 'server' && !song.isDeleted)
      .toList(growable: false);
  if (catalogueSongs.isEmpty) {
    throw const CollectionLinkException(
      'Only catalogue songs can be shared as an import link.',
    );
  }
  if (catalogueSongs.length > maximumCollectionLinkSongs) {
    throw const CollectionLinkException(
      "Share at most 300 catalogue songs per link.",
    );
  }
  final payload = {
    'v': 1,
    'name': collection.name,
    'songs': catalogueSongs.map((song) => song.id).toList(growable: false),
  };
  final encoded = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  if (encoded.length > maximumCollectionLinkLength ||
      collection.name.trim().isEmpty) {
    throw const CollectionLinkException(
      "This list is too large for an import link. Use a text or PDF export.",
    );
  }
  final link = Uri(
    scheme: 'https',
    host: 'nani-samireddy.github.io',
    path: '/praise-catalog/list',
    queryParameters: {'p': encoded},
  );
  // Keep the producer and consumer contract identical, including ID validation.
  parseCollectionLink(link);
  return link;
}

SharedCollectionPayload parseCollectionLink(Uri uri) {
  if (!_isPraiseCollectionLink(uri)) {
    throw const CollectionLinkException('This is not a Praise list link.');
  }
  final encoded = (uri.queryParameters['p'] ?? uri.fragment).trim();
  if (encoded.isEmpty || encoded.length > maximumCollectionLinkLength) {
    throw const CollectionLinkException('This Praise list link is invalid.');
  }

  late final Object? decoded;
  try {
    decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
    );
  } on Object catch (_) {
    throw const CollectionLinkException('This Praise list link is invalid.');
  }
  if (decoded is! Map<String, Object?> || decoded['v'] != 1) {
    throw const CollectionLinkException(
      'This Praise list version is unsupported.',
    );
  }
  final name = decoded['name'];
  final songs = decoded['songs'];
  if (name is! String || name.trim().isEmpty) {
    throw const CollectionLinkException('This Praise list is missing a name.');
  }
  if (songs is! List<Object?> ||
      songs.isEmpty ||
      songs.length > maximumCollectionLinkSongs) {
    throw const CollectionLinkException(
      'This Praise list has an invalid size.',
    );
  }
  final ids = <String>[];
  final seen = <String>{};
  for (final value in songs) {
    if (value is! String || value.trim().isEmpty) {
      throw const CollectionLinkException(
        'This Praise list contains an invalid song.',
      );
    }
    final id = value.trim();
    if (seen.add(id)) ids.add(id);
  }
  return SharedCollectionPayload(
    name: name.trim(),
    songIds: ids,
    duplicateCount: songs.length - ids.length,
  );
}

bool _isPraiseCollectionLink(Uri uri) {
  final isHttpsLink =
      uri.scheme == 'https' &&
      uri.host == 'nani-samireddy.github.io' &&
      uri.path == '/praise-catalog/list';
  final isAppLink = uri.scheme == 'praise' && uri.host == 'list';
  return isHttpsLink || isAppLink;
}
