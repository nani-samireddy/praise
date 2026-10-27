import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/presentation/collection_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/data/telugu_font.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../songs/presentation/formatted_lyrics.dart';
import '../../songs/presentation/lyrics_reading_surface.dart';
import '../../songs/presentation/song_providers.dart';
import 'performance_session.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key, required this.songId, this.collectionId});
  final String songId;
  final String? collectionId;

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen>
    with WidgetsBindingObserver {
  late final PerformanceSession session;
  late String current;
  ScrollController? scroll;
  double? size;

  @override
  void initState() {
    super.initState();
    current = widget.songId;
    session = PerformanceSession(ref.read(screenAwakeProvider));
    session.addListener(refresh);
    WidgetsBinding.instance.addObserver(this);
    session.lifecycle(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      session.lifecycle(state);

  void saveScroll() {
    if (scroll?.hasClients == true) session.offsets[current] = scroll!.offset;
  }

  void select(String id) {
    saveScroll();
    // The keyed lyrics subtree detaches before the old controller is disposed.
    final old = scroll;
    setState(() {
      current = id;
      scroll = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(refresh);
    session.dispose();
    scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(songProvider(current));
    final collectionId = widget.collectionId;
    final list = collectionId == null
        ? null
        : ref.watch(collectionSongsProvider(collectionId));
    final ids = list?.asData?.value.map((s) => s.id).toList() ?? <String>[];
    final previous = adjacentSong(ids, current, -1);
    final next = adjacentSong(ids, current, 1);
    final fontSize =
        size ?? ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final font = ref.watch(teluguFontProvider).valueOrNull ?? TeluguFont.system;
    final mode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Exit performance mode',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Performance mode'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (collectionId != null) ...[
                control(
                  'Previous song',
                  Icons.skip_previous,
                  previous == null ? null : () => select(previous),
                ),
                control(
                  'Next song',
                  Icons.skip_next,
                  next == null ? null : () => select(next),
                ),
              ],
              control(
                'Smaller lyrics',
                Icons.text_decrease,
                fontSize <= 16
                    ? null
                    : () => setState(() => size = (fontSize - 2).clamp(16, 48)),
              ),
              control(
                'Larger lyrics',
                Icons.text_increase,
                fontSize >= 48
                    ? null
                    : () => setState(() => size = (fontSize + 2).clamp(16, 48)),
              ),
              control(
                session.keepAwake ? 'Allow screen sleep' : 'Keep screen awake',
                session.keepAwake ? Icons.light_mode : Icons.bedtime_outlined,
                session.toggleAwake,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (session.awakeUnavailable)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Keep awake unavailable. Your screen may sleep.'),
            ),
          if (collectionId != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                list?.hasError == true
                    ? 'Couldn’t load list order.'
                    : list?.isLoading == true
                    ? 'Loading list order…'
                    : !ids.contains(current)
                    ? 'Song no longer in this list. Choose a song to continue.'
                    : '${ids.indexOf(current) + 1} of ${ids.length}',
              ),
            ),
          if (collectionId != null &&
              list?.asData != null &&
              !ids.contains(current) &&
              ids.isNotEmpty)
            TextButton(
              onPressed: () => select(ids.first),
              child: const Text('Continue from first song'),
            ),
          if (collectionId != null && list?.hasError == true)
            TextButton(
              onPressed: () =>
                  ref.invalidate(collectionSongsProvider(collectionId)),
              child: const Text('Retry list'),
            ),
          Expanded(
            child: song.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(songProvider(current)),
                  child: const Text('Retry song'),
                ),
              ),
              data: (value) {
                if (value == null) {
                  return const Center(
                    child: Text('This song is no longer available.'),
                  );
                }
                scroll ??= ScrollController(
                  initialScrollOffset: session.offsets[current] ?? 0,
                );
                final english = value.englishBody?.trim();
                final hasEnglish = english != null && english.isNotEmpty;
                final primary =
                    mode != LyricsDisplayMode.english || !hasEnglish;
                return ListView(
                  key: ValueKey(current),
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontFamily: font.fontFamily),
                    ),
                    const SizedBox(height: 24),
                    if (value.body.trim().isNotEmpty || hasEnglish)
                      LyricsReadingSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (primary)
                              FormattedLyrics(
                                body: value.body,
                                fontSize: fontSize,
                                fontFamily: font.fontFamily,
                                expandCounts: false,
                              ),
                            if (hasEnglish &&
                                mode != LyricsDisplayMode.primary) ...[
                              const SizedBox(height: 24),
                              FormattedLyrics(
                                body: english,
                                fontSize: fontSize,
                                fontFamily: null,
                                expandCounts: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (value.imagePath != null)
                      Image.file(
                        File(value.imagePath!),
                        errorBuilder: (_, _, _) =>
                            const Text('Saved photo unavailable.'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget control(String label, IconData icon, VoidCallback? action) =>
      IconButton.filledTonal(
        tooltip: label,
        onPressed: action,
        icon: Icon(icon),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      );
}
