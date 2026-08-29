import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../songs/presentation/song_list_card.dart';
import '../data/collection_sharing_service.dart';
import 'collection_dialogs.dart';
import 'collection_providers.dart';

enum _CollectionAction {
  copy,
  shareText,
  shareLink,
  shareImage,
  sharePdf,
  rename,
  delete,
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider(collectionId));
    final songs = ref.watch(collectionSongsProvider(collectionId));
    final value = collection.valueOrNull;
    final songItems = songs.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(value?.name ?? 'List'),
        actions: [
          if (value != null && songItems != null)
            Builder(
              builder: (actionContext) => PopupMenuButton<_CollectionAction>(
                tooltip: 'List sharing and actions',
                icon: const Icon(Icons.ios_share_outlined),
                onSelected: (action) =>
                    _handleAction(actionContext, ref, value, songItems, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _CollectionAction.copy,
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('Copy text'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CollectionAction.shareText,
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Share text'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CollectionAction.shareLink,
                    child: ListTile(
                      leading: Icon(Icons.link_outlined),
                      title: Text('Share link'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CollectionAction.shareImage,
                    child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Share image'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CollectionAction.sharePdf,
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Share PDF'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!value.isSystem) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _CollectionAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rename'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _CollectionAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
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

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    SongCollection collection,
    List<Song> songs,
    _CollectionAction action,
  ) async {
    switch (action) {
      case _CollectionAction.copy:
        try {
          await ref
              .read(collectionSharingServiceProvider)
              .copyCollection(collection, songs);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('List copied.')));
        } catch (_) {
          if (context.mounted) _showShareFailure(context, 'copy');
        }
        return;
      case _CollectionAction.shareText:
        try {
          final renderBox = context.findRenderObject() as RenderBox?;
          final origin = renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size;
          await ref
              .read(collectionSharingServiceProvider)
              .shareCollection(collection, songs, sharePositionOrigin: origin);
        } catch (_) {
          if (context.mounted) _showShareFailure(context, 'share');
        }
        return;
      case _CollectionAction.shareLink:
        try {
          await ref
              .read(collectionSharingServiceProvider)
              .shareCollectionLink(
                collection,
                songs,
                sharePositionOrigin: _shareOrigin(context),
              );
        } catch (_) {
          if (context.mounted) _showShareFailure(context, 'share');
        }
        return;
      case _CollectionAction.shareImage:
        try {
          final includeSongs = await _chooseExportContent(context, 'image');
          if (includeSongs == null || !context.mounted) return;
          await ref
              .read(collectionSharingServiceProvider)
              .shareCollectionImage(
                collection,
                songs,
                includeSongs: includeSongs,
                sharePositionOrigin: _shareOrigin(context),
              );
        } on ExportImageTooLargeException {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This list is too long for an image. Use PDF.'),
            ),
          );
        } catch (_) {
          if (context.mounted) _showShareFailure(context, 'share');
        }
        return;
      case _CollectionAction.sharePdf:
        try {
          final includeSongs = await _chooseExportContent(context, 'PDF');
          if (includeSongs == null || !context.mounted) return;
          await ref
              .read(collectionSharingServiceProvider)
              .shareCollectionPdf(
                collection,
                songs,
                includeSongs: includeSongs,
                sharePositionOrigin: _shareOrigin(context),
              );
        } catch (_) {
          if (context.mounted) _showShareFailure(context, 'share');
        }
        return;
      case _CollectionAction.rename:
        await _rename(context, ref, collection);
        return;
      case _CollectionAction.delete:
        await _delete(context, ref, collection);
        return;
    }
  }

  Future<bool?> _chooseExportContent(BuildContext context, String format) {
    return showModalBottomSheet<bool>(
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
                  'Export $format',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: const Text('Song list only'),
                subtitle: const Text('Titles, English titles, and authors'),
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('Full songs'),
                subtitle: const Text(
                  'Include Telugu and English lyrics for every song',
                ),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Rect? _shareOrigin(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
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

  void _showShareFailure(BuildContext context, String action) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not $action the list.')));
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    debugPrint('Collection detail action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
