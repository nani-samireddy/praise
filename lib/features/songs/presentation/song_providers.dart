import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../custom_songs/data/custom_song_image_store.dart';
import '../data/song_repository.dart';
import '../data/song_notes_repository.dart';

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return DriftSongRepository(
    ref.watch(databaseProvider),
    imageStore: LocalCustomSongImageStore(),
    onChanged: () => ref.read(songIndexRevisionProvider.notifier).state++,
  );
});

final songNotesRepositoryProvider = Provider<SongNotesRepository>((ref) {
  return DriftSongNotesRepository(ref.watch(databaseProvider));
});

// All successful catalogue and custom-song mutations refresh the local index.
final songIndexRevisionProvider = StateProvider<int>((ref) => 0);

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

final songNoteProvider = StreamProvider.family<SongNote?, String>((ref, id) {
  return ref.watch(songNotesRepositoryProvider).watchNote(id);
});

class PagedSongsState {
  const PagedSongsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isSearching = false,
    this.search = '',
    this.error,
  });

  final List<SongIndexEntry> items;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSearching;
  // Query that produced the displayed rows, including during a pending search.
  final String search;
  final Object? error;
}

final pagedSongsProvider =
    AsyncNotifierProvider<PagedSongsController, PagedSongsState>(
      PagedSongsController.new,
    );

class PagedSongsController extends AsyncNotifier<PagedSongsState> {
  static const _pageSize = 60;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  @override
  PagedSongsState build() {
    ref.listen(
      songSearchProvider,
      (_, next) => _schedule(next, debounce: true),
    );
    ref.listen(songIndexRevisionProvider, (_, next) {
      _schedule(ref.read(songSearchProvider), debounce: false);
    });
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _debounce?.cancel();
    });
    _disposed = false;
    _debounce = Timer(
      Duration.zero,
      () => _schedule(ref.read(songSearchProvider), debounce: false),
    );
    return const PagedSongsState(items: [], hasMore: false, isSearching: true);
  }

  void _schedule(String query, {required bool debounce}) {
    _debounce?.cancel();
    final generation = ++_generation;
    final current = state.valueOrNull;
    state = AsyncData(
      PagedSongsState(
        items: current?.items ?? [],
        hasMore: false,
        search: current?.search ?? '',
        isSearching: true,
      ),
    );
    if (debounce && query.trim().isNotEmpty) {
      _debounce = Timer(
        const Duration(milliseconds: 250),
        () => _search(query.trim(), generation),
      );
    } else {
      unawaited(_search(query.trim(), generation));
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> retry() async {
    if (state.valueOrNull?.hasMore == true) {
      await loadMore();
    } else {
      _schedule(ref.read(songSearchProvider), debounce: false);
    }
  }

  Future<void> _search(String query, int generation) async {
    try {
      final items = await _fetchPage(search: query, offset: 0);
      if (!_isCurrent(generation)) return;
      state = AsyncData(
        PagedSongsState(
          items: _visiblePage(items),
          hasMore: items.length > _pageSize,
          search: query,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = AsyncData(
        PagedSongsState(
          items: state.valueOrNull?.items ?? [],
          hasMore: false,
          search: state.valueOrNull?.search ?? '',
          error: error,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isSearching ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      PagedSongsState(
        items: current.items,
        hasMore: true,
        search: current.search,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await _fetchPage(
        search: current.search,
        offset: current.items.length,
      );
      if (!_isCurrent(generation)) return;
      state = AsyncData(
        PagedSongsState(
          items: [...current.items, ..._visiblePage(page)],
          hasMore: page.length > _pageSize,
          search: current.search,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = AsyncData(
        PagedSongsState(
          items: current.items,
          hasMore: true,
          search: current.search,
          error: error,
        ),
      );
    }
  }

  Future<List<SongIndexEntry>> _fetchPage({
    required String search,
    required int offset,
  }) => ref
      .read(songRepositoryProvider)
      .fetchSongIndexPage(search: search, limit: _pageSize + 1, offset: offset);

  List<SongIndexEntry> _visiblePage(List<SongIndexEntry> items) =>
      items.take(_pageSize).toList(growable: false);
}
