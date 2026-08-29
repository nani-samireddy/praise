import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../custom_songs/data/custom_song_image_store.dart';
import '../data/song_repository.dart';

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return DriftSongRepository(
    ref.watch(databaseProvider),
    imageStore: LocalCustomSongImageStore(),
  );
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

class PagedSongsState {
  const PagedSongsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<SongIndexEntry> items;
  final bool hasMore;
  final bool isLoadingMore;

  PagedSongsState copyWith({
    List<SongIndexEntry>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PagedSongsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final pagedSongsProvider =
    AsyncNotifierProvider<PagedSongsController, PagedSongsState>(
      PagedSongsController.new,
    );

class PagedSongsController extends AsyncNotifier<PagedSongsState> {
  static const _pageSize = 60;

  @override
  Future<PagedSongsState> build() async {
    final search = ref.watch(songSearchProvider);
    final items = await _fetchPage(search: search, offset: 0);
    return PagedSongsState(
      items: _visiblePage(items),
      hasMore: items.length > _pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final search = ref.read(songSearchProvider);
    try {
      final nextPage = await _fetchPage(
        search: search,
        offset: current.items.length,
      );
      final nextItems = [...current.items, ..._visiblePage(nextPage)];
      state = AsyncData(
        PagedSongsState(items: nextItems, hasMore: nextPage.length > _pageSize),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<List<SongIndexEntry>> _fetchPage({
    required String search,
    required int offset,
  }) {
    return ref
        .read(songRepositoryProvider)
        .fetchSongIndexPage(
          search: search,
          limit: _pageSize + 1,
          offset: offset,
        );
  }

  List<SongIndexEntry> _visiblePage(List<SongIndexEntry> items) {
    if (items.length <= _pageSize) return items;
    return items.take(_pageSize).toList(growable: false);
  }
}
