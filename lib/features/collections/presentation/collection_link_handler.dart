import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/collection_link_codec.dart';
import '../../catalogue_sync/presentation/catalogue_sync_providers.dart';
import 'collection_providers.dart';

class CollectionLinkHandler extends ConsumerStatefulWidget {
  const CollectionLinkHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CollectionLinkHandler> createState() =>
      _CollectionLinkHandlerState();
}

class _CollectionLinkHandlerState extends ConsumerState<CollectionLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  var _handling = false;

  @override
  void initState() {
    super.initState();
    _handleInitialLink();
    _subscription = _appLinks.uriLinkStream.listen(_handleLink);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) await _handleLink(uri);
  }

  Future<void> _handleLink(Uri uri) async {
    if (_handling || !mounted) return;
    late final SharedCollectionPayload payload;
    try {
      payload = parseCollectionLink(uri);
    } on CollectionLinkException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    _handling = true;
    try {
      while (mounted) {
        final preview = await ref
            .read(collectionsRepositoryProvider)
            .previewImport(payload.songIds);
        if (!mounted) return;
        final decision = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Add "${payload.name}"?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${preview.songs.length} matching songs • ${preview.missingIds.length} missing • ${payload.duplicateCount} duplicates removed. Creates a new local list.',
                  ),
                  for (var i = 0; i < preview.songs.length; i++)
                    Text('${i + 1}. ${preview.songs[i].title}'),
                  if (preview.missingIds.isNotEmpty)
                    Text(
                      'Missing IDs: ${preview.missingIds.join(", ")}\nRefresh songs, then retry this link, or explicitly add only the matches.',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'retry'),
                child: const Text('Retry matches'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'refresh'),
                child: const Text('Refresh songs'),
              ),
              if (preview.songs.isNotEmpty)
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, 'add'),
                  child: Text(
                    preview.missingIds.isEmpty
                        ? 'Add list'
                        : 'Add matching songs only',
                  ),
                ),
            ],
          ),
        );
        if (decision == 'refresh') {
          await ref.read(catalogueSyncControllerProvider.notifier).sync();
          continue;
        }
        if (decision == 'retry') continue;
        if (decision != 'add' || !mounted) return;
        final id = await ref
            .read(collectionsRepositoryProvider)
            .importCollection(
              name: payload.name,
              songIds: preview.songs.map((song) => song.id).toList(),
            );
        if (!mounted) return;
        context.go('/lists/$id');
        break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added "${payload.name}".')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn’t add this list. Refresh your songs and try again.',
          ),
        ),
      );
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
