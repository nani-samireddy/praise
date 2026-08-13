import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import 'song_providers.dart';

class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(songSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider);
    final search = ref.watch(songSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Praise',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(songSearchProvider.notifier).state = value;
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search title or author',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(
              child: songs.when(
                data: (items) => _SongList(items: items, search: search),
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, stackTrace) =>
                    _SongsError(onRetry: () => ref.invalidate(songsProvider)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({required this.items, required this.search});

  final List<Song> items;
  final String search;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptySongs(hasSearch: search.trim().isNotEmpty);
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _SongCard(song: items[index]),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final englishTitle = song.englishTitle;
    final author = song.author;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/songs/${song.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.music_note),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (englishTitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        englishTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (author != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySongs extends StatelessWidget {
  const _EmptySongs({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off_outlined, size: 52),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No songs found' : 'No songs available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try another title or author.'
                  : 'Your offline song library is empty.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongsError extends StatelessWidget {
  const _SongsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 16),
            Text(
              'Could not open the song library',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
