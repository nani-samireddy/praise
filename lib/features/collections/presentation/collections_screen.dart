import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import 'collection_providers.dart';
import 'collection_dialogs.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        label: const Text('New list'),
      ),
      body: collections.when(
        data: (items) {
          if (items.isEmpty) return const _EmptyCollections();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  onTap: () => context.push('/lists/${item.collection.id}'),
                  leading: CircleAvatar(
                    child: Icon(
                      item.collection.isSystem
                          ? Icons.person_outline
                          : Icons.queue_music,
                    ),
                  ),
                  title: Text(
                    item.collection.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.songCount} ${item.songCount == 1 ? 'song' : 'songs'}',
                  ),
                  trailing: item.collection.isSystem
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          tooltip: 'List actions',
                          onSelected: (action) {
                            if (action == 'rename') {
                              _renameCollection(context, ref, item.collection);
                            } else if (action == 'delete') {
                              _deleteCollection(context, ref, item.collection);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
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
            onPressed: () => ref.invalidate(collectionsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
    );
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final name = await showCollectionNameDialog(context, title: 'New list');
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
    ).showSnackBar(const SnackBar(content: Text('Could not update the list.')));
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
              'Create your first custom song and My Songs will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
