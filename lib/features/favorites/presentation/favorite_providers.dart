import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return DriftFavoritesRepository(ref.watch(databaseProvider));
});

final favoriteSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(favoritesRepositoryProvider).watchFavorites();
});

final isFavoriteProvider = StreamProvider.family<bool, String>((ref, songId) {
  return ref.watch(favoritesRepositoryProvider).watchIsFavorite(songId);
});
