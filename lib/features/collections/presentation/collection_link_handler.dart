import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/collection_link_codec.dart';
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
    } on CollectionLinkException {
      return;
    }
    _handling = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add shared list?'),
          content: Text(
            '"${payload.name}" contains ${payload.songIds.length} songs. '
            'It will be added as a new list on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add list'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final id = await ref
          .read(collectionsRepositoryProvider)
          .importCollection(name: payload.name, songIds: payload.songIds);
      if (!mounted) return;
      context.go('/lists/$id');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added "${payload.name}".')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not add this list. Refresh the catalogue and try again.',
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
