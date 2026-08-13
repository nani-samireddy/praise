import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../favorites/presentation/favorite_button.dart';

class SongListCard extends ConsumerWidget {
  const SongListCard({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final englishTitle = song.englishTitle;
    final author = song.author;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/songs/${song.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.music_note),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (song.source == 'custom') ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Custom song',
                            child: Icon(
                              Icons.edit_note,
                              size: 19,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (englishTitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        englishTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (author != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
              FavoriteButton(songId: song.id),
            ],
          ),
        ),
      ),
    );
  }
}
