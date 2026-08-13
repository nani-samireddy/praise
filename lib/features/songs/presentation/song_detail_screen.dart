import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'song_providers.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songProvider(songId));

    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: song.when(
        data: (value) {
          if (value == null) return const _SongNotFound();
          return _SongReader(song: value);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) =>
            _DetailError(onRetry: () => ref.invalidate(songProvider(songId))),
      ),
    );
  }
}

class _SongReader extends StatelessWidget {
  const _SongReader({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final englishTitle = song.englishTitle;
    final englishBody = song.englishBody;
    final author = song.author;

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            song.title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
          ),
          if (englishTitle != null) ...[
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
          _LyricsSection(label: 'Lyrics', body: song.body),
          if (englishBody != null) ...[
            const SizedBox(height: 32),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),
            _LyricsSection(label: 'English lyrics', body: englishBody),
          ],
        ],
      ),
    );
  }
}

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({required this.label, required this.body});

  final String label;
  final String body;

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
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontSize: 19, height: 1.7),
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
