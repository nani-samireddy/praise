import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../settings/data/telugu_font.dart';
import '../../settings/presentation/settings_providers.dart';

class SongListCard extends ConsumerWidget {
  SongListCard({super.key, required Song song})
    : id = song.id,
      title = song.title,
      englishTitle = song.englishTitle,
      author = song.author,
      source = song.source;

  const SongListCard.index({
    super.key,
    required this.id,
    required this.title,
    required this.source,
    this.englishTitle,
    this.author,
  });

  final String id;
  final String title;
  final String? englishTitle;
  final String? author;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teluguFont =
        ref.watch(teluguFontProvider).valueOrNull ?? TeluguFont.system;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push('/songs/$id'),
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        minVerticalPadding: 8,
        visualDensity: const VisualDensity(vertical: -1),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: teluguFont.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (source == 'custom') ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Your song',
                child: Icon(
                  Icons.edit_note_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        subtitle: englishTitle == null && author == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  [?englishTitle, ?author].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
        trailing: FavoriteButton(songId: id),
      ),
    );
  }
}
