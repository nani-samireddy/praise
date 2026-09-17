import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../data/collection_link_codec.dart';
import '../data/collection_sharing_service.dart';
import 'collection_providers.dart';
import 'collection_dialogs.dart';

enum _ListAction { shareLink, rename, delete }

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final _searchController = TextEditingController();
  var _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lists',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCollection(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Create a list'),
      ),
      body: collections.when(
        data: (items) {
          if (items.isEmpty) return const _EmptyCollections();
          final query = _search.trim().toLowerCase();
          final filteredItems = query.isEmpty
              ? items
              : items
                    .where(
                      (item) =>
                          item.collection.name.toLowerCase().contains(query),
                    )
                    .toList();
          return Column(
            children: [
              _SearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                onClear: () => setState(() {
                  _searchController.clear();
                  _search = '';
                }),
              ),
              Expanded(
                child: filteredItems.isEmpty
                    ? const _NoListMatches()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                6,
                                4,
                              ),
                              visualDensity: const VisualDensity(vertical: -1),
                              onTap: () =>
                                  context.push('/lists/${item.collection.id}'),
                              leading: Icon(
                                item.collection.isSystem
                                    ? Icons.person_outline
                                    : Icons.queue_music_outlined,
                              ),
                              title: Text(
                                item.collection.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.songCount} ${item.songCount == 1 ? 'song' : 'songs'}',
                              ),
                              trailing: Builder(
                                builder: (actionContext) =>
                                    PopupMenuButton<_ListAction>(
                                      tooltip: 'List options',
                                      onSelected: (action) => _handleListAction(
                                        actionContext,
                                        ref,
                                        item.collection,
                                        item.songCount,
                                        action,
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: _ListAction.shareLink,
                                          child: ListTile(
                                            leading: Icon(Icons.link_outlined),
                                            title: Text('Share list link'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        if (!item.collection.isSystem) ...[
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: _ListAction.rename,
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.edit_outlined,
                                              ),
                                              title: Text('Rename'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: _ListAction.delete,
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.delete_outline,
                                              ),
                                              title: Text('Delete'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.playlist_remove_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  'Couldn’t load your lists',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(collectionsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleListAction(
    BuildContext context,
    WidgetRef ref,
    SongCollection collection,
    int songCount,
    _ListAction action,
  ) async {
    switch (action) {
      case _ListAction.shareLink:
        await _shareCollectionLink(context, ref, collection, songCount);
        return;
      case _ListAction.rename:
        await _renameCollection(context, ref, collection);
        return;
      case _ListAction.delete:
        await _deleteCollection(context, ref, collection);
        return;
    }
  }

  Future<void> _shareCollectionLink(
    BuildContext context,
    WidgetRef ref,
    SongCollection collection,
    int songCount,
  ) async {
    if (songCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add songs before sharing this list.')),
      );
      return;
    }

    try {
      final songs = await ref
          .read(collectionsRepositoryProvider)
          .watchCollectionSongs(collection.id)
          .first;
      if (!context.mounted) return;
      await ref
          .read(collectionSharingServiceProvider)
          .shareCollectionLink(
            collection,
            songs,
            sharePositionOrigin: _shareOrigin(context),
          );
    } on CollectionLinkException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t share the list link.')),
        );
      }
    }
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final name = await showCollectionNameDialog(
      context,
      title: 'Create a list',
    );
    if (name == null || !context.mounted) return;
    try {
      final id = await ref
          .read(collectionsRepositoryProvider)
          .createCollection(name);
      if (context.mounted) context.push('/lists/$id');
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _renameCollection(
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

  Future<void> _deleteCollection(
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
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Couldn’t update the list.')));
  }

  Rect? _shareOrigin(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    debugPrint('Collection action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'No lists yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a list for practice or worship. My Songs appears automatically when you add a song.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
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
          hintText: 'Search lists',
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

class _NoListMatches extends StatelessWidget {
  const _NoListMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No matching lists'));
  }
}
