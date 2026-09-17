import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../songs/presentation/song_list_card.dart';
import 'favorite_providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _searchController = TextEditingController();
  var _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoriteSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: favorites.when(
        data: (songs) {
          if (songs.isEmpty) return const _EmptyFavorites();
          final query = _search.trim().toLowerCase();
          final filteredSongs = query.isEmpty
              ? songs
              : songs
                    .where(
                      (song) => [song.title, song.englishTitle, song.author]
                          .whereType<String>()
                          .any((value) => value.toLowerCase().contains(query)),
                    )
                    .toList();
          return Column(
            children: [
              _SearchField(
                controller: _searchController,
                hintText: 'Search favorites',
                onChanged: (value) => setState(() => _search = value),
                onClear: () => setState(() {
                  _searchController.clear();
                  _search = '';
                }),
              ),
              Expanded(
                child: filteredSongs.isEmpty
                    ? const _NoFavoriteMatches()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: filteredSongs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) =>
                            SongListCard(song: filteredSongs[index]),
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: FilledButton.tonal(
            onPressed: () => ref.invalidate(favoriteSongsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
  }
}

class _NoFavoriteMatches extends StatelessWidget {
  const _NoFavoriteMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No matching favorites'));
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'No favorites yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the heart beside a song to save it here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/songs'),
              icon: const Icon(Icons.library_music_outlined),
              label: const Text('Browse songs'),
            ),
          ],
        ),
      ),
    );
  }
}
