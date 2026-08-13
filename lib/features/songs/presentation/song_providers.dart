import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/song_repository.dart';

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return DriftSongRepository(ref.watch(databaseProvider));
});

final songSearchProvider = StateProvider<String>((ref) => '');

final songsProvider = StreamProvider<List<Song>>((ref) {
  final search = ref.watch(songSearchProvider);
  return ref.watch(songRepositoryProvider).watchSongs(search: search);
});

final songsForSearchProvider = StreamProvider.family<List<Song>, String>((
  ref,
  search,
) {
  return ref.watch(songRepositoryProvider).watchSongs(search: search);
});

final songProvider = StreamProvider.family<Song?, String>((ref, id) {
  return ref.watch(songRepositoryProvider).watchSong(id);
});
