import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../songs/presentation/song_list_card.dart';
import '../../../shared/presentation/action_sheet.dart';
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
              builder: (actionContext) => IconButton(
                tooltip: 'Share list',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () async {
                  ScaffoldMessenger.of(actionContext).hideCurrentSnackBar();
                  final action = await _showCollectionShareSheet(actionContext);
                  if (action == null || !actionContext.mounted) return;
                  await _handleAction(
                    actionContext,
                    ref,
                    value,
                    songItems,
                    action,
                  );
                },
              ),
            ),
          if (value != null && songItems != null && !value.isSystem)
            PopupMenuButton<_CollectionAction>(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) =>
                  _handleAction(context, ref, value, songItems, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CollectionAction.rename,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename list'),
                  ),
                ),
                PopupMenuItem(
                  value: _CollectionAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete list'),
                  ),
                ),
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
            return _EmptyCollection(
              isSystem: value?.isSystem == true,
              onAdd: value != null && !value.isSystem
                  ? () => context.push('/lists/$collectionId/add')
                  : null,
            );
          }
          if (value?.isSystem != false) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) => SongListCard(song: items[index]),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(context, ref, items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final song = items[index];
              return Padding(
                key: ValueKey(song.id),
                padding: const EdgeInsets.only(bottom: 6),
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

  Future<_CollectionAction?> _showCollectionShareSheet(BuildContext context) {
    return showActionSheet<_CollectionAction>(
      context: context,
      title: 'Share list',
      items: const [
        ActionSheetItem(
          value: _CollectionAction.copy,
          icon: Icons.copy_outlined,
          title: 'Copy text',
          subtitle: 'Copy the song titles and lyrics',
        ),
        ActionSheetItem(
          value: _CollectionAction.shareText,
          icon: Icons.share_outlined,
          title: 'Share text',
          subtitle: 'Best for messages and WhatsApp',
        ),
        ActionSheetItem(
          value: _CollectionAction.shareLink,
          icon: Icons.link_outlined,
          title: 'Share list link',
          subtitle: 'Lets another Praise user add this list',
        ),
        ActionSheetItem(
          value: _CollectionAction.shareImage,
          icon: Icons.image_outlined,
          title: 'Share image',
          subtitle: 'Create a visual list or full-song export',
        ),
        ActionSheetItem(
          value: _CollectionAction.sharePdf,
          icon: Icons.picture_as_pdf_outlined,
          title: 'Share PDF',
          subtitle: 'Best for printing or complete song sets',
        ),
      ],
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
        final includeSongs = await _chooseExportContent(context, 'image');
        if (includeSongs == null || !context.mounted) return;
        _showPreparingShareMessage(context, 'Preparing image...');
        var keepResultMessageVisible = false;
        try {
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          keepResultMessageVisible = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This list is too long for an image. Use PDF.'),
            ),
          );
        } catch (_) {
          keepResultMessageVisible = true;
          if (context.mounted) _showShareFailure(context, 'share');
        } finally {
          if (context.mounted && !keepResultMessageVisible) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        }
        return;
      case _CollectionAction.sharePdf:
        final includeSongs = await _chooseExportContent(context, 'PDF');
        if (includeSongs == null || !context.mounted) return;
        _showPreparingShareMessage(context, 'Preparing PDF...');
        var keepResultMessageVisible = false;
        try {
          await ref
              .read(collectionSharingServiceProvider)
              .shareCollectionPdf(
                collection,
                songs,
                includeSongs: includeSongs,
                sharePositionOrigin: _shareOrigin(context),
              );
        } catch (_) {
          keepResultMessageVisible = true;
          if (context.mounted) _showShareFailure(context, 'share');
        } finally {
          if (context.mounted && !keepResultMessageVisible) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
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

  void _showPreparingShareMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(minutes: 1),
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(message),
            ],
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

  void _showShareFailure(BuildContext context, String action) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not $action the list.')));
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    debugPrint('Collection detail action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.isSystem, required this.onAdd});

  final bool isSystem;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSystem ? Icons.person_outline : Icons.queue_music_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isSystem ? 'No custom songs yet' : 'This list is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isSystem
                  ? 'Songs you add or scan will appear here automatically.'
                  : 'Add songs to prepare this set.',
              textAlign: TextAlign.center,
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add songs'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
