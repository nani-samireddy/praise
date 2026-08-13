import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/collections_repository.dart';

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return DriftCollectionsRepository(ref.watch(databaseProvider));
});

final collectionsProvider = StreamProvider<List<CollectionSummary>>((ref) {
  return ref.watch(collectionsRepositoryProvider).watchCollections();
});

final collectionProvider = StreamProvider.family<SongCollection?, String>((
  ref,
  id,
) {
  return ref.watch(collectionsRepositoryProvider).watchCollection(id);
});

final collectionSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  id,
) {
  return ref.watch(collectionsRepositoryProvider).watchCollectionSongs(id);
});

final collectionIdsForSongProvider = StreamProvider.family<Set<String>, String>(
  (ref, songId) {
    return ref
        .watch(collectionsRepositoryProvider)
        .watchCollectionIdsForSong(songId);
  },
);
