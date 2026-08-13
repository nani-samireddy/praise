import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../songs/presentation/song_providers.dart';
import 'collection_providers.dart';

class AddSongsScreen extends ConsumerStatefulWidget {
  const AddSongsScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends ConsumerState<AddSongsScreen> {
  var _search = '';
  final _updating = <String>{};

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider(widget.collectionId));
    final songs = ref.watch(songsForSearchProvider(_search));
    final selected = ref.watch(collectionSongsProvider(widget.collectionId));
    final selectedIds =
        selected.valueOrNull?.map((song) => song.id).toSet() ?? {};
    final editable = collection.valueOrNull?.isSystem == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Add songs')),
      body: !editable && collection.hasValue
          ? const Center(child: Text('This list is managed automatically.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      hintText: 'Search songs',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: songs.when(
                    data: (items) => ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final song = items[index];
                        final isSelected = selectedIds.contains(song.id);
                        final isUpdating = _updating.contains(song.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: isUpdating
                              ? null
                              : (_) => _toggleSong(song.id, isSelected),
                          title: Text(song.title),
                          subtitle: song.englishTitle == null
                              ? null
                              : Text(song.englishTitle!),
                          secondary: isUpdating
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                    error: (error, stackTrace) =>
                        const Center(child: Text('Could not load songs.')),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _toggleSong(String songId, bool isSelected) async {
    setState(() => _updating.add(songId));
    try {
      final repository = ref.read(collectionsRepositoryProvider);
      if (isSelected) {
        await repository.removeSong(widget.collectionId, songId);
      } else {
        await repository.addSong(widget.collectionId, songId);
      }
    } catch (error, stackTrace) {
      debugPrint('Song picker update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the list.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(songId));
    }
  }
}
