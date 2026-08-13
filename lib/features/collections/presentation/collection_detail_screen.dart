import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../songs/presentation/song_list_card.dart';
import 'collection_dialogs.dart';
import 'collection_providers.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider(collectionId));
    final songs = ref.watch(collectionSongsProvider(collectionId));
    final value = collection.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(value?.name ?? 'List'),
        actions: [
          if (value != null && !value.isSystem)
            PopupMenuButton<String>(
              tooltip: 'List actions',
              onSelected: (action) {
                if (action == 'rename') {
                  _rename(context, ref, value);
                } else if (action == 'delete') {
                  _delete(context, ref, value);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      floatingActionButton: value != null && !value.isSystem
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/lists/$collectionId/add'),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add songs'),
            )
          : null,
      body: songs.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                value?.isSystem == true
                    ? 'Create a custom song to add it here.'
                    : 'No songs in this list yet.',
              ),
            );
          }
          if (value?.isSystem != false) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => SongListCard(song: items[index]),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(context, ref, items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final song = items[index];
              return Padding(
                key: ValueKey(song.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    onTap: () => context.push('/songs/${song.id}'),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(song.title),
                    subtitle: song.englishTitle == null
                        ? null
                        : Text(song.englishTitle!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FavoriteButton(songId: song.id),
                        IconButton(
                          onPressed: () => _remove(context, ref, song.id),
                          tooltip: 'Remove from list',
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: FilledButton.tonal(
            onPressed: () =>
                ref.invalidate(collectionSongsProvider(collectionId)),
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SongCollection collection,
  ) async {
    final name = await showCollectionNameDialog(
      context,
      title: 'Rename list',
      initialValue: collection.name,
    );
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .renameCollection(collection.id, name);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SongCollection collection,
  ) async {
    final confirmed = await confirmCollectionDeletion(context, collection.name);
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .deleteCollection(collection.id);
      if (context.mounted) context.go('/lists');
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String songId,
  ) async {
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .removeSong(collectionId, songId);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = songs.map((song) => song.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .reorderSongs(collectionId, ids);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not update the list.')));
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    debugPrint('Collection detail action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
