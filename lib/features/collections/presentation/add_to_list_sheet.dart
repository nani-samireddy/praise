import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'collection_dialogs.dart';
import 'collection_providers.dart';

class AddToListSheet extends ConsumerWidget {
  const AddToListSheet({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final selected = ref.watch(collectionIdsForSongProvider(songId));
    final selectedIds = selected.valueOrNull ?? {};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add to list',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create new list'),
              onTap: () => _createAndAdd(context, ref),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: collections.when(
                data: (items) {
                  final editable = items
                      .where((item) => !item.collection.isSystem)
                      .toList();
                  if (editable.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No custom lists yet. Create one above.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: editable.length,
                    itemBuilder: (context, index) {
                      final item = editable[index];
                      final isSelected = selectedIds.contains(
                        item.collection.id,
                      );
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(item.collection.name),
                        subtitle: Text('${item.songCount} songs'),
                        onChanged: (_) => _toggle(
                          context,
                          ref,
                          item.collection.id,
                          isSelected,
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, stackTrace) => const Text(
                  'Could not load lists.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final name = await showCollectionNameDialog(context, title: 'New list');
    if (name == null || !context.mounted) return;
    try {
      final repository = ref.read(collectionsRepositoryProvider);
      final id = await repository.createCollection(name);
      await repository.addSong(id, songId);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String collectionId,
    bool isSelected,
  ) async {
    try {
      final repository = ref.read(collectionsRepositoryProvider);
      if (isSelected) {
        await repository.removeSong(collectionId, songId);
      } else {
        await repository.addSong(collectionId, songId);
      }
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
    debugPrint('List update failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
