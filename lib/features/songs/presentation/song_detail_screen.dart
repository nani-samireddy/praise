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
import '../../../shared/presentation/action_sheet.dart';
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
          body: _SongReader(
            song: value,
            appBar: SliverAppBar.medium(
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
                  builder: (actionContext) => IconButton(
                    tooltip: 'Share song',
                    icon: const Icon(Icons.ios_share_outlined),
                    onPressed: () async {
                      ScaffoldMessenger.of(actionContext).hideCurrentSnackBar();
                      final action = await _showSongShareSheet(
                        actionContext,
                        value,
                      );
                      if (action == null || !actionContext.mounted) return;
                      await _handleSongAction(
                        actionContext,
                        ref,
                        value,
                        action,
                      );
                    },
                  ),
                ),
                PopupMenuButton<_SongAction>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) =>
                      _handleSongAction(context, ref, value, action),
                  itemBuilder: (context) => [
                    if (value.source == 'server')
                      const PopupMenuItem(
                        value: _SongAction.report,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Report this song'),
                        ),
                      ),
                    if (value.source == 'custom') ...[
                      const PopupMenuItem(
                        value: _SongAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit song'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _SongAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete song'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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

  Future<_SongAction?> _showSongShareSheet(BuildContext context, Song song) {
    return showActionSheet<_SongAction>(
      context: context,
      title: 'Share song',
      items: [
        const ActionSheetItem(
          value: _SongAction.copy,
          icon: Icons.copy_outlined,
          title: 'Copy text',
          subtitle: 'Copy the full song to your clipboard',
        ),
        const ActionSheetItem(
          value: _SongAction.shareText,
          icon: Icons.share_outlined,
          title: 'Share text',
          subtitle: 'Best for messages and WhatsApp',
        ),
        ActionSheetItem(
          value: _SongAction.shareImage,
          icon: Icons.image_outlined,
          title: song.imagePath == null
              ? 'Share image'
              : 'Share original photo',
          subtitle: song.imagePath == null
              ? 'Create a visual lyric card'
              : 'Share the saved source photo',
        ),
        const ActionSheetItem(
          value: _SongAction.sharePdf,
          icon: Icons.picture_as_pdf_outlined,
          title: 'Share PDF',
          subtitle: 'Best for printing or long songs',
        ),
      ],
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
        _showPreparingShareMessage(context, 'Preparing image...');
        var keepResultMessageVisible = false;
        try {
          await ref
              .read(songSharingServiceProvider)
              .shareSongImage(song, sharePositionOrigin: _shareOrigin(context));
        } on ExportImageTooLargeException {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          keepResultMessageVisible = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This song is too long for an image. Use PDF.'),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          keepResultMessageVisible = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the song image.')),
          );
        } finally {
          if (context.mounted && !keepResultMessageVisible) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        }
        return;
      case _SongAction.sharePdf:
        _showPreparingShareMessage(context, 'Preparing PDF...');
        var keepResultMessageVisible = false;
        try {
          await ref
              .read(songSharingServiceProvider)
              .shareSongPdf(song, sharePositionOrigin: _shareOrigin(context));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          keepResultMessageVisible = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the song PDF.')),
          );
        } finally {
          if (context.mounted && !keepResultMessageVisible) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
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

  void _showPreparingShareMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(minutes: 1),
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
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
  Widget build(BuildContext context) => AppBar(title: const Text('Song'));
}

class _SongReader extends ConsumerStatefulWidget {
  const _SongReader({required this.song, required this.appBar});

  final Song song;
  final SliverAppBar appBar;

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
        child: CustomScrollView(
          slivers: [
            widget.appBar,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (hasPrimaryLyrics || englishBody != null)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _chooseFontSize,
                          icon: const Icon(Icons.text_fields, size: 18),
                          label: Text('Text ${_fontSize.round()}'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _expandCounts = !_expandCounts;
                          }),
                          icon: Icon(
                            _expandCounts
                                ? Icons.unfold_less
                                : Icons.unfold_more,
                            size: 18,
                          ),
                          label: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Text(
                              _expandCounts ? 'Compact' : 'Expand ×N',
                              key: ValueKey(_expandCounts),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (showEnglishTitle) ...[
                    const SizedBox(height: 12),
                    Text(
                      englishTitle,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (author != null) ...[
                    const SizedBox(height: 12),
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
                  const SizedBox(height: 24),
                  if (widget.song.maleVideoUrl != null ||
                      widget.song.femaleVideoUrl != null) ...[
                    _PracticeVideos(song: widget.song),
                    const SizedBox(height: 28),
                  ],
                  if (imagePath != null) ...[
                    _SongPhoto(imagePath: imagePath),
                    if (hasPrimaryLyrics || showEnglish)
                      const SizedBox(height: 28),
                  ],
                  if (showPrimary && hasPrimaryLyrics)
                    _LyricsSection(
                      label: showEnglish ? 'Original lyrics' : 'Lyrics',
                      body: widget.song.body,
                      fontSize: _fontSize,
                      fontFamily: teluguFont.fontFamily,
                      expandCounts: _expandCounts,
                    ),
                  if (showEnglish) ...[
                    const SizedBox(height: 32),
                    if (showPrimary && hasPrimaryLyrics)
                      Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 20),
                    _LyricsSection(
                      label: 'English lyrics',
                      body: englishBody,
                      fontSize: _fontSize,
                      fontFamily: null,
                      expandCounts: _expandCounts,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseFontSize() async {
    var draft = _fontSize;
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lyrics text size',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Slider(
                        value: draft,
                        min: _minimumFontSize,
                        max: _maximumFontSize,
                        divisions: 22,
                        label: '${draft.round()}',
                        semanticFormatterCallback: (value) =>
                            'Text size ${value.round()}',
                        onChanged: (value) =>
                            setSheetState(() => draft = value),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 28)),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() => draft = 19),
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, draft),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _fontSize = selected;
      _scaleStartFontSize = selected;
    });
    await ref.read(settingsRepositoryProvider).setLyricsFontSize(selected);
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
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: FormattedLyrics(
            key: ValueKey(expandCounts),
            body: body,
            fontSize: fontSize,
            fontFamily: fontFamily,
            expandCounts: expandCounts,
          ),
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
