import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../collections/presentation/add_to_list_sheet.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_providers.dart';
import 'formatted_lyrics.dart';
import 'song_providers.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songProvider(songId));

    return song.when(
      data: (value) {
        if (value == null) {
          return const Scaffold(appBar: _LyricsAppBar(), body: _SongNotFound());
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lyrics'),
            actions: [
              FavoriteButton(songId: value.id),
              IconButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: false,
                  builder: (context) => AddToListSheet(songId: value.id),
                ),
                tooltip: 'Add to list',
                icon: const Icon(Icons.playlist_add),
              ),
              if (value.source == 'custom') ...[
                IconButton(
                  onPressed: () =>
                      context.push('/custom-song/${value.id}/edit'),
                  tooltip: 'Edit song',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _deleteSong(context, ref, value),
                  tooltip: 'Delete song',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          body: _SongReader(song: value),
        );
      },
      loading: () => const Scaffold(
        appBar: _LyricsAppBar(),
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: const _LyricsAppBar(),
        body: _DetailError(onRetry: () => ref.invalidate(songProvider(songId))),
      ),
    );
  }

  Future<void> _deleteSong(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete custom song?'),
        content: Text('"${song.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(songRepositoryProvider).deleteCustomSong(song.id);
      if (!context.mounted) return;
      context.go('/songs');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the song.')),
      );
    }
  }
}

class _LyricsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LyricsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Lyrics'));
}

class _SongReader extends ConsumerStatefulWidget {
  const _SongReader({required this.song});

  final Song song;

  @override
  ConsumerState<_SongReader> createState() => _SongReaderState();
}

class _SongReaderState extends ConsumerState<_SongReader> {
  static const _minimumFontSize = 16.0;
  static const _maximumFontSize = 38.0;
  var _fontSize = 19.0;
  var _scaleStartFontSize = 19.0;
  var _loadedFontSize = false;
  var _expandCounts = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final englishTitle = widget.song.englishTitle;
    final englishBody = widget.song.englishBody;
    final author = widget.song.author;
    final storedFontSize = ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final displayMode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;
    if (!_loadedFontSize) {
      _fontSize = storedFontSize;
      _scaleStartFontSize = storedFontSize;
      _loadedFontSize = true;
    }
    final showPrimary =
        displayMode != LyricsDisplayMode.english || englishBody == null;
    final showEnglish =
        englishBody != null && displayMode != LyricsDisplayMode.primary;
    final showPrimaryTitle =
        displayMode != LyricsDisplayMode.english || englishTitle == null;
    final showEnglishTitle =
        englishTitle != null && displayMode != LyricsDisplayMode.primary;

    return GestureDetector(
      onScaleStart: (details) => _scaleStartFontSize = _fontSize,
      onScaleUpdate: (details) {
        if (details.pointerCount < 2) return;
        final next = (_scaleStartFontSize * details.scale).clamp(
          _minimumFontSize,
          _maximumFontSize,
        );
        if (next != _fontSize) setState(() => _fontSize = next);
      },
      onScaleEnd: (details) =>
          ref.read(settingsRepositoryProvider).setLyricsFontSize(_fontSize),
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                Icon(
                  Icons.pinch_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Pinch to resize lyrics',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _expandCounts = !_expandCounts;
                  }),
                  icon: Icon(
                    _expandCounts ? Icons.unfold_less : Icons.unfold_more,
                    size: 18,
                  ),
                  label: Text(_expandCounts ? 'Compact' : 'Expand ×N'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (showPrimaryTitle)
              Text(
                widget.song.title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
              ),
            if (showEnglishTitle) ...[
              const SizedBox(height: 8),
              Text(
                englishTitle,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (author != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      author,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            if (showPrimary)
              _LyricsSection(
                label: showEnglish ? 'Primary lyrics' : 'Lyrics',
                body: widget.song.body,
                fontSize: _fontSize,
                expandCounts: _expandCounts,
              ),
            if (showEnglish) ...[
              const SizedBox(height: 32),
              if (showPrimary) Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 24),
              _LyricsSection(
                label: 'English lyrics',
                body: englishBody,
                fontSize: _fontSize,
                expandCounts: _expandCounts,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({
    required this.label,
    required this.body,
    required this.fontSize,
    required this.expandCounts,
  });

  final String label;
  final String body;
  final double fontSize;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        FormattedLyrics(
          body: body,
          fontSize: fontSize,
          expandCounts: expandCounts,
        ),
      ],
    );
  }
}

class _SongNotFound extends StatelessWidget {
  const _SongNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off_outlined, size: 52),
            const SizedBox(height: 16),
            Text(
              'Song not found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('Try again'),
      ),
    );
  }
}
