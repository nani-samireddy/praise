import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../catalogue_sync/presentation/catalogue_sync_feedback.dart';
import '../../catalogue_sync/presentation/catalogue_sync_progress_view.dart';
import '../../catalogue_sync/presentation/catalogue_sync_providers.dart';
import 'song_list_card.dart';
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

  Future<void> _showAddSongOptions() async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Add song',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Enter manually'),
                subtitle: const Text('Type or paste the song details'),
                onTap: () => Navigator.pop(sheetContext, '/custom-song/new'),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan photo'),
                subtitle: const Text('Recognize Telugu and English offline'),
                onTap: () => Navigator.pop(sheetContext, '/custom-song/scan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (route != null && mounted) {
      await context.push(route);
      if (mounted) ref.invalidate(pagedSongsProvider);
    }
  }

  Future<void> _refreshCatalogue() async {
    try {
      final result = await ref
          .read(catalogueSyncControllerProvider.notifier)
          .sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(catalogueSyncSuccessMessage(result))),
      );
      ref.invalidate(pagedSongsProvider);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(catalogueSyncErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(pagedSongsProvider);
    final search = ref.watch(songSearchProvider);
    final syncProgress = ref.watch(catalogueSyncProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Praise',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSongOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add song'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(songSearchProvider.notifier).state = value;
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search title or author',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
            if (syncProgress != null)
              CatalogueSyncProgressView(progress: syncProgress),
            Expanded(
              child: songs.when(
                data: (state) => _SongList(
                  items: state.items,
                  search: search,
                  hasMore: state.hasMore,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: () =>
                      ref.read(pagedSongsProvider.notifier).loadMore(),
                  onRefresh: _refreshCatalogue,
                ),
                loading: () => const _SongListSkeleton(),
                error: (error, stackTrace) => _SongsError(
                  onRetry: () => ref.invalidate(pagedSongsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongListSkeleton extends StatefulWidget {
  const _SongListSkeleton();

  @override
  State<_SongListSkeleton> createState() => _SongListSkeletonState();
}

class _SongListSkeletonState extends State<_SongListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween(
      begin: 0.42,
      end: 0.78,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _opacity,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
          itemCount: 8,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) => Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: index.isEven ? 0.62 : 0.78,
                          child: Container(
                            height: 17,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        FractionallySizedBox(
                          widthFactor: index.isEven ? 0.42 : 0.56,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: placeholder,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({
    required this.items,
    required this.search,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final List<SongIndexEntry> items;
  final String search;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            _EmptySongs(hasSearch: search.trim().isNotEmpty),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 480 &&
            hasMore &&
            !isLoadingMore) {
          onLoadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
          itemCount: items.length + (hasMore || isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            final song = items[index];
            return SongListCard.index(
              id: song.id,
              title: song.title,
              englishTitle: song.englishTitle,
              author: song.author,
              source: song.source,
            );
          },
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
    return Column(
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
