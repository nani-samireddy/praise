import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
import '../../settings/presentation/feature_providers.dart';
import '../../settings/data/feature_flags.dart';
import '../../../shared/presentation/action_sheet.dart';
import '../data/song_sharing_service.dart';
import 'formatted_lyrics.dart';
import 'chord_transposer.dart';
import 'metronome_controller.dart';
import 'song_providers.dart';
import 'structured_lyrics.dart';

enum _SongAction { copy, shareText, shareImage, sharePdf, report, edit, delete }

enum _SongControlsPosition { auto, left, right }

String? _extractOriginalKey(String? structureJson) {
  if (structureJson == null) return null;
  try {
    final decoded = jsonDecode(structureJson);
    final key = decoded is Map ? decoded['originalKey'] : null;
    return key is String && key.trim().isNotEmpty ? key : null;
  } on Object {
    return null;
  }
}

int _extractCapo(String? structureJson) {
  if (structureJson == null) return 0;
  try {
    final decoded = jsonDecode(structureJson);
    final capo = decoded is Map ? decoded['capo'] : null;
    return capo is num ? capo.toInt().clamp(0, 12) : 0;
  } on Object {
    return 0;
  }
}

bool _hasHarmonyParts(String? structureJson) {
  if (structureJson == null) return false;
  try {
    final decoded = jsonDecode(structureJson);
    final parts = decoded is Map ? decoded['harmonyParts'] : null;
    if (parts is! List) return false;
    return parts.any((part) {
      if (part is! Map) return false;
      final lines = part['lines'];
      return lines is List && lines.whereType<Map>().isNotEmpty;
    });
  } on Object {
    return false;
  }
}

bool _hasStructuredTransliteration(String? structureJson) {
  if (structureJson == null) return false;
  try {
    final decoded = jsonDecode(structureJson);
    final sections = decoded is Map ? decoded['sections'] : null;
    if (sections is! List) return false;
    var hasLines = false;
    for (final section in sections.whereType<Map>()) {
      final lines = section['lines'];
      if (lines is! List) continue;
      for (final line in lines.whereType<Map>()) {
        final segments = line['segments'];
        if (segments is! List || segments.isEmpty) return false;
        final segmentMaps = segments.whereType<Map>().toList();
        if (segmentMaps.length != segments.length ||
            segmentMaps.any(
              (segment) =>
                  segment['transliteration']?.toString().trim().isEmpty !=
                  false,
            )) {
          return false;
        }
        hasLines = true;
      }
    }
    return hasLines;
  } on Object {
    return false;
  }
}

class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  late final MetronomeController _metronomeController;
  var _transposeSemitones = 0;

  @override
  void initState() {
    super.initState();
    _metronomeController = MetronomeController();
  }

  @override
  void dispose() {
    _metronomeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SongDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _transposeSemitones = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(songProvider(widget.songId));

    return song.when(
      data: (value) {
        if (value == null) {
          return const Scaffold(appBar: _LyricsAppBar(), body: _SongNotFound());
        }
        return Scaffold(
          body: _SongReader(
            song: value,
            metronomeController: _metronomeController,
            transposeSemitones: _transposeSemitones,
            onTransposeChanged: (value) =>
                setState(() => _transposeSemitones = value),
            onMetronomeDetails: () => _showMetronomeSheet(context),
            appBar: SliverAppBar.medium(
              title: _SongAppBarTitle(
                title: value.title,
                englishTitle: value.englishTitle,
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
                    tooltip: 'Share',
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
                          title: Text('Report a problem'),
                        ),
                      ),
                    if (value.source == 'custom') ...[
                      const PopupMenuItem(
                        value: _SongAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _SongAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
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
        body: _DetailError(
          onRetry: () => ref.invalidate(songProvider(widget.songId)),
        ),
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
          title: 'Copy lyrics',
          subtitle: 'Copy the lyrics to your clipboard',
        ),
        const ActionSheetItem(
          value: _SongAction.shareText,
          icon: Icons.share_outlined,
          title: 'Share as text',
          subtitle: 'Works well in messaging apps',
        ),
        ActionSheetItem(
          value: _SongAction.shareImage,
          icon: Icons.image_outlined,
          title: song.imagePath == null ? 'Share as image' : 'Share photo',
          subtitle: song.imagePath == null
              ? 'Create a clean lyrics image'
              : 'Share the saved song photo',
        ),
        const ActionSheetItem(
          value: _SongAction.sharePdf,
          icon: Icons.picture_as_pdf_outlined,
          title: 'Share as PDF',
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
              .showSnackBar(const SnackBar(content: Text('Lyrics copied.')));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t copy the lyrics.')),
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
            const SnackBar(content: Text('Couldn’t share the song.')),
          );
        }
        return;
      case _SongAction.shareImage:
        _showPreparingShareMessage(context, 'Preparing image…');
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
              content: Text(
                'This song is too long for an image. Try PDF instead.',
              ),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          keepResultMessageVisible = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t share the song image.')),
          );
        } finally {
          if (context.mounted && !keepResultMessageVisible) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        }
        return;
      case _SongAction.sharePdf:
        _showPreparingShareMessage(context, 'Preparing PDF…');
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
            const SnackBar(content: Text('Couldn’t share the song PDF.')),
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

  Future<void> _showMetronomeSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) =>
          _MetronomeSheet(controller: _metronomeController),
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
        title: const Text('Delete this song?'),
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
        const SnackBar(content: Text('Couldn’t delete the song.')),
      );
    }
  }
}

class _CycleSettingButton<T> extends StatelessWidget {
  const _CycleSettingButton({
    required this.label,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.valueIcon,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) valueLabel;
  final IconData Function(T value) valueIcon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentIndex = values.indexOf(value);
    final nextIndex = (currentIndex + 1) % values.length;
    final currentLabel = valueLabel(value);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(currentLabel),
      trailing: Semantics(
        button: true,
        label: '$label: $currentLabel',
        hint: 'Tap to change',
        child: IconButton.filledTonal(
          tooltip: '$label: $currentLabel. Tap to change.',
          onPressed: () => onChanged(values[nextIndex]),
          icon: Icon(valueIcon(value)),
        ),
      ),
    );
  }
}

class _SongControlsPanel extends StatelessWidget {
  const _SongControlsPanel({
    required this.fontSize,
    required this.expandCounts,
    required this.repeatsEnabled,
    required this.hasEnglish,
    required this.displayMode,
    required this.transposeSemitones,
    required this.originalKey,
    required this.chordDisplayEnabled,
    required this.showChords,
    required this.capoShapesEnabled,
    required this.capo,
    required this.showGuitarShapes,
    required this.harmonyEnabled,
    required this.hasHarmonyParts,
    required this.showHarmonyParts,
    required this.chordTransposeEnabled,
    required this.metronomeEnabled,
    required this.metronomeRunning,
    required this.adaptiveControlsEnabled,
    required this.controlsPosition,
    required this.onControlsPositionChanged,
    required this.onFontSize,
    required this.onFullLyricsChanged,
    required this.onDisplayModeChanged,
    required this.onChordsChanged,
    required this.onGuitarShapesChanged,
    required this.onHarmonyPartsChanged,
    required this.onTransposeChanged,
    required this.onMetronomeToggle,
    required this.onMetronomeDetails,
  });

  final double fontSize;
  final bool expandCounts;
  final bool repeatsEnabled;
  final bool hasEnglish;
  final LyricsDisplayMode displayMode;
  final int transposeSemitones;
  final String? originalKey;
  final bool chordDisplayEnabled;
  final bool showChords;
  final bool capoShapesEnabled;
  final int capo;
  final bool showGuitarShapes;
  final bool harmonyEnabled;
  final bool hasHarmonyParts;
  final bool showHarmonyParts;
  final bool chordTransposeEnabled;
  final bool metronomeEnabled;
  final bool metronomeRunning;
  final bool adaptiveControlsEnabled;
  final _SongControlsPosition controlsPosition;
  final ValueChanged<_SongControlsPosition> onControlsPositionChanged;
  final Future<void> Function() onFontSize;
  final ValueChanged<bool> onFullLyricsChanged;
  final ValueChanged<LyricsDisplayMode> onDisplayModeChanged;
  final ValueChanged<bool> onChordsChanged;
  final ValueChanged<bool> onGuitarShapesChanged;
  final ValueChanged<bool> onHarmonyPartsChanged;
  final ValueChanged<int> onTransposeChanged;
  final VoidCallback onMetronomeToggle;
  final VoidCallback onMetronomeDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final targetKey = originalKey == null
        ? null
        : transposeKey(originalKey!, transposeSemitones);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Song controls',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.text_fields_outlined),
              title: const Text('Text size'),
              subtitle: const Text('Pinch to resize the lyrics'),
              trailing: OutlinedButton(
                onPressed: onFontSize,
                child: Text(fontSize.round().toString()),
              ),
            ),
            if (adaptiveControlsEnabled) ...[
              const SizedBox(height: 8),
              _CycleSettingButton<_SongControlsPosition>(
                label: 'Control position',
                value: controlsPosition,
                values: _SongControlsPosition.values,
                valueLabel: (value) => switch (value) {
                  _SongControlsPosition.auto => 'Auto',
                  _SongControlsPosition.left => 'Left',
                  _SongControlsPosition.right => 'Right',
                },
                valueIcon: (value) => switch (value) {
                  _SongControlsPosition.auto => Icons.auto_mode_outlined,
                  _SongControlsPosition.left => Icons.format_align_left,
                  _SongControlsPosition.right => Icons.format_align_right,
                },
                onChanged: onControlsPositionChanged,
              ),
              if (controlsPosition == _SongControlsPosition.auto)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Tilt your phone gently to move the controls.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (repeatsEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.unfold_more),
                title: const Text('Show full lyrics'),
                subtitle: const Text('Expand all repeated lines and sections'),
                value: expandCounts,
                onChanged: onFullLyricsChanged,
              ),
            if (hasEnglish) ...[
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              _CycleSettingButton<LyricsDisplayMode>(
                label: 'Lyrics display',
                value: displayMode,
                values: const [
                  LyricsDisplayMode.both,
                  LyricsDisplayMode.primary,
                  LyricsDisplayMode.english,
                  LyricsDisplayMode.lineByLine,
                ],
                valueLabel: (value) => switch (value) {
                  LyricsDisplayMode.primary => 'Original only',
                  LyricsDisplayMode.english => 'English only',
                  LyricsDisplayMode.both => 'Sections',
                  LyricsDisplayMode.lineByLine => 'Line by line',
                },
                valueIcon: (value) => switch (value) {
                  LyricsDisplayMode.primary => Icons.lyrics_outlined,
                  LyricsDisplayMode.english => Icons.translate_outlined,
                  LyricsDisplayMode.both => Icons.view_agenda_outlined,
                  LyricsDisplayMode.lineByLine => Icons.compare_arrows,
                },
                onChanged: onDisplayModeChanged,
              ),
            ],
            if (chordDisplayEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('Chords'),
                subtitle: const Text('Show chord names above the lyrics'),
                value: showChords,
                onChanged: onChordsChanged,
              ),
            if (capoShapesEnabled && showChords && capo > 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('Guitar chord shapes'),
                subtitle: Text('Capo $capo · Show playable shapes'),
                value: showGuitarShapes,
                onChanged: onGuitarShapesChanged,
              ),
            if (harmonyEnabled && hasHarmonyParts)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Harmony parts'),
                subtitle: const Text('Show harmony lines'),
                value: showHarmonyParts,
                onChanged: onHarmonyPartsChanged,
              ),
            if (chordTransposeEnabled) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note_outlined),
                title: const Text('Transpose'),
                subtitle: Text(
                  targetKey == null
                      ? _transposeLabel(transposeSemitones)
                      : '$originalKey → $targetKey',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Lower key',
                      onPressed: transposeSemitones <= -12
                          ? null
                          : () => onTransposeChanged(transposeSemitones - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      _transposeLabel(transposeSemitones),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Raise key',
                      onPressed: transposeSemitones >= 12
                          ? null
                          : () => onTransposeChanged(transposeSemitones + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
            if (metronomeEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: onMetronomeDetails,
                leading: const Icon(Icons.av_timer_outlined),
                title: const Text('Metronome'),
                subtitle: const Text('Keep a steady practice beat'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Metronome options',
                      onPressed: onMetronomeDetails,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    Switch(
                      value: metronomeRunning,
                      onChanged: (_) => onMetronomeToggle(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _transposeLabel(int semitones) {
    if (semitones == 0) return 'Original';
    return '${semitones > 0 ? '+' : ''}$semitones';
  }
}

class _MetronomeSheet extends StatelessWidget {
  const _MetronomeSheet({required this.controller});

  final MetronomeController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bpm = controller.bpm.toDouble();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metronome',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.isRunning
                                ? 'Playing ${controller.bpm} BPM'
                                : 'Set a steady practice tempo',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: controller.toggle,
                      icon: Icon(
                        controller.isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(controller.isRunning ? 'Stop' : 'Start'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: _BeatIndicator(
                    currentBeat: controller.currentBeat,
                    beatsPerBar: controller.beatsPerBar,
                    isRunning: controller.isRunning,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      '${controller.bpm}',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BPM',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: bpm,
                  min: MetronomeController.minBpm.toDouble(),
                  max: MetronomeController.maxBpm.toDouble(),
                  divisions:
                      MetronomeController.maxBpm - MetronomeController.minBpm,
                  label: '${controller.bpm} BPM',
                  onChanged: (value) => controller.setBpm(value.round()),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => controller.setBpm(controller.bpm - 1),
                      child: const Text('-1'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => controller.setBpm(controller.bpm + 1),
                      child: const Text('+1'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        initialValue: controller.beatsPerBar,
                        decoration: const InputDecoration(
                          labelText: 'Beats per bar',
                        ),
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2 beats')),
                          DropdownMenuItem(value: 3, child: Text('3 beats')),
                          DropdownMenuItem(value: 4, child: Text('4 beats')),
                          DropdownMenuItem(value: 6, child: Text('6 beats')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.setBeatsPerBar(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accent beat 1'),
                  subtitle: const Text('Make the first beat stronger'),
                  value: controller.accentFirstBeat,
                  onChanged: controller.setAccentFirstBeat,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tick sound'),
                  value: controller.soundEnabled,
                  onChanged: controller.setSoundEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vibrate on each beat'),
                  value: controller.hapticsEnabled,
                  onChanged: controller.setHapticsEnabled,
                ),
                if (controller.isRunning) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You can close this sheet. The metronome will keep playing until you stop it or leave this song.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BeatIndicator extends StatelessWidget {
  const _BeatIndicator({
    required this.currentBeat,
    required this.beatsPerBar,
    required this.isRunning,
  });

  final int currentBeat;
  final int beatsPerBar;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: [
        for (var beat = 1; beat <= beatsPerBar; beat++)
          SizedBox.square(
            dimension: 18,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 90),
                scale: beat == currentBeat && isRunning ? 1.45 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: beat == currentBeat && isRunning
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LyricsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LyricsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Song'));
}

class _SongAppBarTitle extends StatelessWidget {
  const _SongAppBarTitle({required this.title, required this.englishTitle});

  final String title;
  final String? englishTitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = englishTitle?.trim();
    if (subtitle == null || subtitle.isEmpty) {
      return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SongReader extends ConsumerStatefulWidget {
  const _SongReader({
    required this.song,
    required this.appBar,
    required this.metronomeController,
    required this.transposeSemitones,
    required this.onTransposeChanged,
    required this.onMetronomeDetails,
  });

  final Song song;
  final SliverAppBar appBar;
  final MetronomeController metronomeController;
  final int transposeSemitones;
  final ValueChanged<int> onTransposeChanged;
  final VoidCallback onMetronomeDetails;

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
  var _showChords = false;
  var _showGuitarShapes = false;
  var _showHarmonyParts = false;
  var _showSongControls = false;
  var _controlsPosition = _SongControlsPosition.auto;
  var _autoControlsOnLeft = false;
  var _adaptiveControlsStarted = false;
  double? _filteredTilt;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _syncAdaptiveControls(bool enabled) {
    if (_adaptiveControlsStarted == enabled) return;
    _adaptiveControlsStarted = enabled;
    if (!enabled) {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
      _filteredTilt = null;
      return;
    }
    _accelerometerSubscription =
        accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval)
            .listen(
              _handleAccelerometerEvent,
              onError: (_) {
                _accelerometerSubscription?.cancel();
                _accelerometerSubscription = null;
              },
              cancelOnError: true,
            );
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (!mounted || !event.x.isFinite) return;
    final previous = _filteredTilt;
    final filtered = previous == null
        ? event.x
        : previous * 0.75 + event.x * 0.25;
    _filteredTilt = filtered;
    const threshold = 1.1;
    final shouldMoveLeft = filtered > threshold
        ? true
        : filtered < -threshold
        ? false
        : null;
    if (shouldMoveLeft == null || shouldMoveLeft == _autoControlsOnLeft) {
      return;
    }
    setState(() => _autoControlsOnLeft = shouldMoveLeft);
  }

  Alignment _controlsAlignment(bool adaptiveControlsEnabled) {
    if (!adaptiveControlsEnabled) return Alignment.centerRight;
    return switch (_controlsPosition) {
      _SongControlsPosition.left => Alignment.centerLeft,
      _SongControlsPosition.right => Alignment.centerRight,
      _SongControlsPosition.auto =>
        _autoControlsOnLeft ? Alignment.centerLeft : Alignment.centerRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final englishBody = widget.song.englishBody;
    final author = widget.song.author;
    final imagePath = widget.song.imagePath;
    final hasPrimaryLyrics = widget.song.body.trim().isNotEmpty;
    final hasStructuredTransliteration = _hasStructuredTransliteration(
      widget.song.structureJson,
    );
    final storedFontSize = ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final displayMode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;
    final teluguFont =
        ref.watch(teluguFontProvider).valueOrNull ?? TeluguFont.system;
    final repeatsEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.repeatExpansion))
            .valueOrNull ??
        true;
    final videosEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.practiceVideos))
            .valueOrNull ??
        true;
    final metronomeEnabled =
        ref.watch(featureEnabledProvider(FeatureKey.metronome)).valueOrNull ??
        true;
    final chordDisplayEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.chordDisplay))
            .valueOrNull ??
        true;
    final capo = _extractCapo(widget.song.structureJson);
    final capoShapesEnabled =
        ref.watch(featureEnabledProvider(FeatureKey.capoShapes)).valueOrNull ??
        true;
    final harmonyEnabled =
        ref.watch(featureEnabledProvider(FeatureKey.harmony)).valueOrNull ??
        true;
    final adaptiveSongControlsEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.adaptiveSongControls))
            .valueOrNull ??
        false;
    if (adaptiveSongControlsEnabled != _adaptiveControlsStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAdaptiveControls(adaptiveSongControlsEnabled);
      });
    }
    final hasHarmonyParts = _hasHarmonyParts(widget.song.structureJson);
    final chordTransposeEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.chordTranspose))
            .valueOrNull ??
        true;
    if (!_loadedFontSize) {
      _fontSize = storedFontSize;
      _scaleStartFontSize = storedFontSize;
      _loadedFontSize = true;
    }
    final showPrimary =
        displayMode != LyricsDisplayMode.english || englishBody == null;
    final showEnglish =
        englishBody != null && displayMode != LyricsDisplayMode.primary;
    final showLineByLine =
        displayMode == LyricsDisplayMode.lineByLine && englishBody != null;
    final controlsAlignment = _controlsAlignment(adaptiveSongControlsEnabled);

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
                  if (hasPrimaryLyrics || englishBody != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _showSongControls = !_showSongControls;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: controlsAlignment,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showSongControls
                                    ? Icons.tune
                                    : Icons.tune_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showSongControls
                                    ? 'Hide controls'
                                    : 'Song controls',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _showSongControls
                          ? AnimatedBuilder(
                              animation: widget.metronomeController,
                              builder: (context, _) => SizedBox(
                                width: double.infinity,
                                child: _SongControlsPanel(
                                  fontSize: _fontSize,
                                  expandCounts: _expandCounts,
                                  repeatsEnabled: repeatsEnabled,
                                  hasEnglish: englishBody != null,
                                  displayMode: displayMode,
                                  transposeSemitones: widget.transposeSemitones,
                                  originalKey: _extractOriginalKey(
                                    widget.song.structureJson,
                                  ),
                                  chordDisplayEnabled:
                                      chordDisplayEnabled &&
                                      widget.song.structureJson != null,
                                  showChords: _showChords,
                                  capoShapesEnabled:
                                      chordDisplayEnabled && capoShapesEnabled,
                                  capo: capo,
                                  showGuitarShapes: _showGuitarShapes,
                                  harmonyEnabled: harmonyEnabled,
                                  hasHarmonyParts: hasHarmonyParts,
                                  showHarmonyParts: _showHarmonyParts,
                                  chordTransposeEnabled:
                                      chordDisplayEnabled &&
                                      _showChords &&
                                      chordTransposeEnabled &&
                                      widget.song.structureJson != null,
                                  metronomeEnabled: metronomeEnabled,
                                  metronomeRunning:
                                      widget.metronomeController.isRunning,
                                  adaptiveControlsEnabled:
                                      adaptiveSongControlsEnabled,
                                  controlsPosition: _controlsPosition,
                                  onControlsPositionChanged: (value) {
                                    setState(() => _controlsPosition = value);
                                  },
                                  onFontSize: _chooseFontSize,
                                  onFullLyricsChanged: (value) => setState(() {
                                    _expandCounts = value;
                                  }),
                                  onDisplayModeChanged: (value) {
                                    ref
                                        .read(settingsRepositoryProvider)
                                        .setLyricsDisplayMode(value);
                                  },
                                  onChordsChanged: (value) => setState(() {
                                    _showChords = value;
                                  }),
                                  onGuitarShapesChanged: (value) =>
                                      setState(() {
                                        _showGuitarShapes = value;
                                      }),
                                  onHarmonyPartsChanged: (value) =>
                                      setState(() {
                                        _showHarmonyParts = value;
                                      }),
                                  onTransposeChanged: widget.onTransposeChanged,
                                  onMetronomeToggle:
                                      widget.metronomeController.toggle,
                                  onMetronomeDetails: widget.onMetronomeDetails,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (videosEnabled &&
                      (widget.song.maleVideoUrl != null ||
                          widget.song.femaleVideoUrl != null)) ...[
                    _PracticeVideos(song: widget.song),
                    const SizedBox(height: 28),
                  ],
                  if (imagePath != null) ...[
                    _SongPhoto(imagePath: imagePath),
                    if (hasPrimaryLyrics || showEnglish)
                      const SizedBox(height: 28),
                  ],
                  if (showLineByLine && hasPrimaryLyrics)
                    _LineByLineLyricsSection(
                      primaryBody: widget.song.body,
                      englishBody: englishBody,
                      structuredJson: hasStructuredTransliteration
                          ? widget.song.structureJson
                          : null,
                      fontSize: _fontSize,
                      primaryFontFamily: teluguFont.fontFamily,
                      expandCounts: _expandCounts,
                      transposeSemitones: widget.transposeSemitones,
                      showChords: chordDisplayEnabled && _showChords,
                      showGuitarShapes:
                          chordDisplayEnabled &&
                          capoShapesEnabled &&
                          _showGuitarShapes,
                      showHarmonyParts: harmonyEnabled && _showHarmonyParts,
                    ),
                  if (!showLineByLine && showPrimary && hasPrimaryLyrics)
                    _LyricsSection(
                      label: showEnglish ? 'Telugu lyrics' : 'Lyrics',
                      body: widget.song.body,
                      fontSize: _fontSize,
                      fontFamily: teluguFont.fontFamily,
                      expandCounts: repeatsEnabled && _expandCounts,
                      structuredJson: widget.song.structureJson,
                      transposeSemitones: widget.transposeSemitones,
                      showChords: chordDisplayEnabled && _showChords,
                      showGuitarShapes:
                          chordDisplayEnabled &&
                          capoShapesEnabled &&
                          _showGuitarShapes,
                      showHarmonyParts: harmonyEnabled && _showHarmonyParts,
                    ),
                  if (!showLineByLine && showEnglish) ...[
                    const SizedBox(height: 32),
                    if (showPrimary && hasPrimaryLyrics)
                      Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 20),
                    _LyricsSection(
                      label: 'English lyrics',
                      body: englishBody,
                      fontSize: _fontSize,
                      fontFamily: null,
                      expandCounts: repeatsEnabled && _expandCounts,
                      structuredJson: hasStructuredTransliteration
                          ? widget.song.structureJson
                          : null,
                      showTransliterationOnly: hasStructuredTransliteration,
                      transposeSemitones: widget.transposeSemitones,
                      showChords: chordDisplayEnabled && _showChords,
                      showGuitarShapes:
                          chordDisplayEnabled &&
                          capoShapesEnabled &&
                          _showGuitarShapes,
                      showHarmonyParts: harmonyEnabled && _showHarmonyParts,
                    ),
                  ],
                  _SongNotesCard(
                    key: ValueKey(widget.song.id),
                    songId: widget.song.id,
                  ),
                  if (author != null && author.trim().isNotEmpty) ...[
                    const SizedBox(height: 36),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'This song is authored by ${author.trim()}.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
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

class _SongNotesCard extends ConsumerStatefulWidget {
  const _SongNotesCard({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<_SongNotesCard> createState() => _SongNotesCardState();
}

class _SongNotesCardState extends ConsumerState<_SongNotesCard> {
  static const _maximumCharacters = 2000;

  late final TextEditingController _controller;
  var _isEditing = false;
  var _isSaving = false;
  var _hasUnsavedChanges = false;
  var _hasLoadedNote = false;
  var _syncingNote = false;
  String? _loadedContent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleDraftChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleDraftChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(songNoteProvider(widget.songId));
    return note.when(
      loading: () => const _SongNotesLoadingCard(),
      error: (error, stackTrace) => _SongNotesErrorCard(
        onRetry: () => ref.invalidate(songNoteProvider(widget.songId)),
      ),
      data: (value) {
        _syncNote(value?.content);
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _hasUnsavedChanges) _confirmDiscard();
          },
          child: _buildCard(context, value),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, SongNote? note) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasNote = note != null && note.content.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'Notes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (hasNote && !_isEditing)
                  IconButton(
                    tooltip: 'Delete note',
                    onPressed: _deleteNote,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (_isEditing)
              _buildEditor(context)
            else if (hasNote)
              _buildSavedNote(context, note.content)
            else
              _buildEmptyState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Private note — only you can see this.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _startEditing,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Add a note'),
        ),
      ],
    );
  }

  Widget _buildSavedNote(BuildContext context, String content) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(content, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _startEditing,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit note'),
          style: TextButton.styleFrom(foregroundColor: colors.primary),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: _maximumCharacters,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Song note',
            hintText: 'Add a private note…',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSaving ? null : _saveNote,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  void _syncNote(String? content) {
    if (_hasLoadedNote && (_isEditing || _loadedContent == content)) return;
    _loadedContent = content;
    _syncingNote = true;
    try {
      _controller.value = TextEditingValue(
        text: content ?? '',
        selection: TextSelection.collapsed(offset: content?.length ?? 0),
      );
    } finally {
      _syncingNote = false;
    }
    _hasLoadedNote = true;
  }

  void _handleDraftChanged() {
    if (_syncingNote || !_hasLoadedNote || !mounted) return;
    final draft = _controller.text.trim();
    setState(() => _hasUnsavedChanges = draft != (_loadedContent ?? ''));
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _controller.text = _loadedContent ?? '';
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveNote() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(songNotesRepositoryProvider)
          .saveNote(widget.songId, _controller.text);
      if (!mounted) return;
      setState(() {
        _loadedContent = _controller.text.trim().isEmpty
            ? null
            : _controller.text.trim();
        _isEditing = false;
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loadedContent == null ? 'Note cleared.' : 'Note saved.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t save the note.')));
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This private note will be permanently removed.'),
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
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(songNotesRepositoryProvider).deleteNote(widget.songId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Note deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t delete the note.')),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this note?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop();
    }
  }
}

class _SongNotesLoadingCard extends StatelessWidget {
  const _SongNotesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.only(top: 32),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _SongNotesErrorCard extends StatelessWidget {
  const _SongNotesErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 32),
      child: ListTile(
        leading: const Icon(Icons.sticky_note_2_outlined),
        title: const Text('Notes unavailable'),
        subtitle: const Text('Couldn’t load this song’s note.'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
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

class _PracticeVideosState extends State<_PracticeVideos>
    with AutomaticKeepAliveClientMixin<_PracticeVideos> {
  YoutubePlayerController? _controller;
  String? _activeVideoId;
  late final List<_PracticeVideo> _videos;

  @override
  void initState() {
    super.initState();
    _videos = [
      if (widget.song.maleVideoUrl case final url?)
        _PracticeVideo(label: 'Male', url: url),
      if (widget.song.femaleVideoUrl case final url?)
        _PracticeVideo(label: 'Female', url: url),
    ];
    // Initialize the first available recording immediately.  Previously the
    // player remained a placeholder until the user tapped the selector.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _videos.isNotEmpty) {
        _selectVideo(_videos.first);
      }
    });
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => _controller != null;

  void _selectVideo(_PracticeVideo video) {
    final videoId = _youtubeVideoId(video.url);
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
    updateKeepAlive();
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Listen',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              for (final video in _videos)
                ButtonSegment(
                  value: video.url,
                  label: Text(video.label),
                  icon: Icon(video.label == 'Male' ? Icons.male : Icons.female),
                ),
            ],
            selected: {_activeUrl},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => _selectVideo(
              _videos.firstWhere((video) => video.url == selection.single),
            ),
          ),
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
            label: const Text('Open in YouTube'),
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
          (video) => _youtubeVideoId(video.url) == videoId,
          orElse: () => _videos.first,
        )
        .url;
  }

  String? _youtubeVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }

    final isYoutube =
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
    if (!isYoutube) return null;

    final watchId = uri.queryParameters['v'];
    if (watchId != null && watchId.isNotEmpty) return watchId;

    if (uri.pathSegments.length >= 2 &&
        const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
      return uri.pathSegments[1];
    }

    return YoutubePlayerController.convertUrlToId(url);
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
          'Saved photo',
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
                      Text('Couldn’t open the saved song photo.'),
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
    this.structuredJson,
    this.showTransliterationOnly = false,
    this.transposeSemitones = 0,
    this.showChords = true,
    this.showGuitarShapes = false,
    this.showHarmonyParts = false,
  });

  final String label;
  final String body;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;
  final String? structuredJson;
  final bool showTransliterationOnly;
  final int transposeSemitones;
  final bool showChords;
  final bool showGuitarShapes;
  final bool showHarmonyParts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: structuredJson != null
              ? StructuredLyrics(
                  json: structuredJson!,
                  fontSize: fontSize,
                  fontFamily: fontFamily,
                  expandCounts: expandCounts,
                  showTransliterationOnly: showTransliterationOnly,
                  transposeSemitones: transposeSemitones,
                  showChords: showChords,
                  showGuitarShapes: showGuitarShapes,
                  showHarmonyParts: showHarmonyParts,
                )
              : FormattedLyrics(
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

class _LineByLineLyricsSection extends StatelessWidget {
  const _LineByLineLyricsSection({
    required this.primaryBody,
    required this.englishBody,
    this.structuredJson,
    required this.fontSize,
    required this.primaryFontFamily,
    required this.expandCounts,
    this.transposeSemitones = 0,
    this.showChords = false,
    this.showGuitarShapes = false,
    this.showHarmonyParts = false,
  });

  final String primaryBody;
  final String englishBody;
  final String? structuredJson;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;
  final int transposeSemitones;
  final bool showChords;
  final bool showGuitarShapes;
  final bool showHarmonyParts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Line by line',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 32),
        structuredJson != null
            ? StructuredLyrics(
                json: structuredJson!,
                fontSize: fontSize,
                fontFamily: primaryFontFamily,
                expandCounts: expandCounts,
                showTransliteration: true,
                transposeSemitones: transposeSemitones,
                showChords: showChords,
                showGuitarShapes: showGuitarShapes,
                showHarmonyParts: showHarmonyParts,
              )
            : BilingualFormattedLyrics(
                primaryBody: primaryBody,
                englishBody: englishBody,
                fontSize: fontSize,
                primaryFontFamily: primaryFontFamily,
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
              'We couldn’t find that song',
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
