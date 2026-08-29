import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/database/app_database.dart';
import '../../../core/export/export_document_renderer.dart';
import '../../collections/presentation/add_to_list_sheet.dart';
import '../../feedback/data/github_feedback_service.dart';
import '../../feedback/presentation/feedback_dialogs.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/data/telugu_font.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/song_sharing_service.dart';
import 'formatted_lyrics.dart';
import 'song_providers.dart';

enum _SongAction { copy, shareText, shareImage, sharePdf, report, edit, delete }

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
            title: Text(
              value.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
              Builder(
                builder: (actionContext) => PopupMenuButton<_SongAction>(
                  tooltip: 'Song sharing and actions',
                  icon: const Icon(Icons.ios_share_outlined),
                  onSelected: (action) =>
                      _handleSongAction(actionContext, ref, value, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _SongAction.copy,
                      child: ListTile(
                        leading: Icon(Icons.copy_outlined),
                        title: Text('Copy song'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _SongAction.shareText,
                      child: ListTile(
                        leading: Icon(Icons.share_outlined),
                        title: Text('Share text'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _SongAction.shareImage,
                      child: ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: Text(
                          value.imagePath == null
                              ? 'Share image'
                              : 'Share original photo',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _SongAction.sharePdf,
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('Share PDF'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (value.source == 'server') ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _SongAction.report,
                        child: ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Report this song'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    if (value.source == 'custom') ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _SongAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit song'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _SongAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete song'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

  Future<void> _handleSongAction(
    BuildContext context,
    WidgetRef ref,
    Song song,
    _SongAction action,
  ) async {
    switch (action) {
      case _SongAction.copy:
        try {
          await ref.read(songSharingServiceProvider).copySong(song);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Song copied.')));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not copy the song.')),
          );
        }
        return;
      case _SongAction.shareText:
        try {
          await ref
              .read(songSharingServiceProvider)
              .shareSong(song, sharePositionOrigin: _shareOrigin(context));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the song.')),
          );
        }
        return;
      case _SongAction.shareImage:
        try {
          await ref
              .read(songSharingServiceProvider)
              .shareSongImage(song, sharePositionOrigin: _shareOrigin(context));
        } on ExportImageTooLargeException {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This song is too long for an image. Use PDF.'),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the song image.')),
          );
        }
        return;
      case _SongAction.sharePdf:
        try {
          await ref
              .read(songSharingServiceProvider)
              .shareSongPdf(song, sharePositionOrigin: _shareOrigin(context));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the song PDF.')),
          );
        }
        return;
      case _SongAction.report:
        await showFeedbackForm(
          context: context,
          service: ref.read(githubFeedbackServiceProvider),
          type: FeedbackFormType.songCorrection,
          song: song,
        );
        return;
      case _SongAction.edit:
        await context.push('/custom-song/${song.id}/edit');
        return;
      case _SongAction.delete:
        await _deleteSong(context, ref, song);
        return;
    }
  }

  Rect? _shareOrigin(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
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
  Widget build(BuildContext context) => AppBar(title: const Text('Song'));
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
    final imagePath = widget.song.imagePath;
    final hasPrimaryLyrics = widget.song.body.trim().isNotEmpty;
    final storedFontSize = ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final displayMode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;
    final teluguFont =
        ref.watch(teluguFontProvider).valueOrNull ?? TeluguFont.system;
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
            if (hasPrimaryLyrics || englishBody != null)
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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: teluguFont.fontFamily,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
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
            if (widget.song.maleVideoUrl != null ||
                widget.song.femaleVideoUrl != null) ...[
              _PracticeVideos(song: widget.song),
              const SizedBox(height: 32),
            ],
            if (imagePath != null) ...[
              _SongPhoto(imagePath: imagePath),
              if (hasPrimaryLyrics || showEnglish) const SizedBox(height: 32),
            ],
            if (showPrimary && hasPrimaryLyrics)
              _LyricsSection(
                label: showEnglish ? 'Primary lyrics' : 'Lyrics',
                body: widget.song.body,
                fontSize: _fontSize,
                fontFamily: teluguFont.fontFamily,
                expandCounts: _expandCounts,
              ),
            if (showEnglish) ...[
              const SizedBox(height: 32),
              if (showPrimary && hasPrimaryLyrics)
                Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 24),
              _LyricsSection(
                label: 'English lyrics',
                body: englishBody,
                fontSize: _fontSize,
                fontFamily: null,
                expandCounts: _expandCounts,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PracticeVideos extends StatefulWidget {
  const _PracticeVideos({required this.song});

  final Song song;

  @override
  State<_PracticeVideos> createState() => _PracticeVideosState();
}

class _PracticeVideosState extends State<_PracticeVideos> {
  YoutubePlayerController? _controller;
  String? _activeVideoId;
  late final List<_PracticeVideo> _videos;

  @override
  void initState() {
    super.initState();
    _videos = [
      if (widget.song.maleVideoUrl case final url?)
        _PracticeVideo(label: 'Male version', url: url),
      if (widget.song.femaleVideoUrl case final url?)
        _PracticeVideo(label: 'Female version', url: url),
    ];
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  void _selectVideo(_PracticeVideo video) {
    final videoId = YoutubePlayerController.convertUrlToId(video.url);
    if (videoId == null) {
      _openExternally(video.url);
      return;
    }
    if (_activeVideoId == videoId) return;
    _controller?.close();
    setState(() {
      _activeVideoId = videoId;
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
          playsInline: true,
        ),
      );
    });
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRACTICE VIDEOS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: [
            for (final video in _videos)
              ButtonSegment(
                value: video.url,
                label: Text(video.label),
                icon: const Icon(Icons.play_circle_outline),
              ),
          ],
          selected: {
            if (_activeVideoId == null) _videos.first.url else _activeUrl,
          },
          onSelectionChanged: (selection) {
            final selected = selection.single;
            _selectVideo(_videos.firstWhere((video) => video.url == selected));
          },
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: controller == null
                ? InkWell(
                    onTap: () => _selectVideo(_videos.first),
                    child: ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 58,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : YoutubePlayer(controller: controller),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openExternally(_activeUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open YouTube'),
          ),
        ),
      ],
    );
  }

  String get _activeUrl {
    final videoId = _activeVideoId;
    if (videoId == null) return _videos.first.url;
    return _videos
        .firstWhere(
          (video) =>
              YoutubePlayerController.convertUrlToId(video.url) == videoId,
          orElse: () => _videos.first,
        )
        .url;
  }
}

class _PracticeVideo {
  const _PracticeVideo({required this.label, required this.url});

  final String label;
  final String url;
}

class _SongPhoto extends StatelessWidget {
  const _SongPhoto({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORIGINAL PHOTO',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: double.infinity,
                maxHeight: 640,
              ),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                  child: Column(
                    children: [
                      Icon(Icons.broken_image_outlined, size: 48),
                      SizedBox(height: 12),
                      Text('The saved song photo could not be opened.'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({
    required this.label,
    required this.body,
    required this.fontSize,
    required this.fontFamily,
    required this.expandCounts,
  });

  final String label;
  final String body;
  final double fontSize;
  final String? fontFamily;
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
        const SizedBox(height: 28),
        FormattedLyrics(
          body: body,
          fontSize: fontSize,
          fontFamily: fontFamily,
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
