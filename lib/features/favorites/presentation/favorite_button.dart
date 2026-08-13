import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorite_providers.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(isFavoriteProvider(songId));

    return favorite.when(
      data: (isFavorite) => IconButton(
        onPressed: () async {
          try {
            await ref
                .read(favoritesRepositoryProvider)
                .setFavorite(songId, isFavorite: !isFavorite);
          } catch (error, stackTrace) {
            debugPrint('Favorite update failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not update favorite.')),
            );
          }
        },
        tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline),
        color: isFavorite ? Theme.of(context).colorScheme.primary : null,
      ),
      loading: () => const IconButton(
        onPressed: null,
        tooltip: 'Loading favorite',
        icon: Icon(Icons.favorite_outline),
      ),
      error: (error, stackTrace) => const IconButton(
        onPressed: null,
        tooltip: 'Favorite unavailable',
        icon: Icon(Icons.favorite_outline),
      ),
    );
  }
}
