import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../collections/presentation/add_to_list_sheet.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/presentation/song_providers.dart';
import '../data/custom_song_image_store.dart';
import '../data/local_song_draft.dart';
import '../data/scanned_song_draft.dart';
import '../data/song_scan_service.dart';

final localSongDraftStoreProvider = Provider<LocalSongDraftStore>((ref) {
  return LocalSongDraftStore(ref.watch(databaseProvider));
});

class CustomSongEditorScreen extends ConsumerStatefulWidget {
  const CustomSongEditorScreen({super.key, this.songId, this.scannedDraft});

  final String? songId;
  final ScannedSongDraft? scannedDraft;

  @override
  ConsumerState<CustomSongEditorScreen> createState() =>
      _CustomSongEditorScreenState();
}

class _CustomSongEditorScreenState
    extends ConsumerState<CustomSongEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _englishTitleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _englishBodyController = TextEditingController();
  final _authorController = TextEditingController();
  final _maleVideoUrlController = TextEditingController();
  final _femaleVideoUrlController = TextEditingController();
  var _initialized = false;
  var _saving = false;
  var _readingImage = false;
  String _scanProgress = 'Reading text from the photo…';
  String? _scanError;
  var _detailsExpanded = false;
  var _draftLoading = false;
  var _draftRecovered = false;
  var _draftChanged = false;
  var _draftCompleted = false;
  var _draftIsScanned = false;
  var _draftAiEnhanced = false;
  var _draftAiFallback = false;
  Timer? _draftSaveTimer;
  Future<void>? _draftInitialization;
  String? _newImagePath;
  String? _existingImagePath;
  var _removeImage = false;

  bool get _isEditing => widget.songId != null;

  @override
  void initState() {
    super.initState();
    _detailsExpanded = widget.songId != null || widget.scannedDraft != null;
    final draft = widget.scannedDraft;
    if (widget.songId == null && draft != null) {
      _titleController.text = draft.title;
      _englishTitleController.text = draft.englishTitle ?? '';
      _bodyController.text = draft.body;
      _englishBodyController.text = draft.englishBody ?? '';
      _authorController.text = draft.author ?? '';
      _newImagePath = draft.imagePath;
      _initialized = true;
      _draftIsScanned = draft.body.trim().isNotEmpty;
      _draftAiEnhanced = draft.aiEnhanced;
      _draftAiFallback = draft.aiFallback;
      _draftLoading = true;
      _draftInitialization = _saveIncomingDraft(draft);
      unawaited(_draftInitialization);
    }
    if (widget.songId == null && draft == null) {
      _draftLoading = true;
      _draftInitialization = _loadDraft();
      unawaited(_draftInitialization);
    }
  }

  Future<void> _pasteLyrics() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no text to paste.')),
      );
      return;
    }
    setState(() {
      _bodyController.text = text;
      _bodyController.selection = TextSelection.collapsed(offset: text.length);
    });
    _scheduleDraftSave();
  }

  Future<void> _readFromImage() async {
    final imagePath = _activeImagePath;
    if (imagePath == null || _readingImage) return;
    setState(() {
      _readingImage = true;
      _scanProgress = 'Reading text from the photo…';
      _scanError = null;
    });
    try {
      final service = ref.read(songScanServiceProvider);
      final recognizedText = await service.recognize(imagePath);
      if (recognizedText.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _scanError = 'No readable lyrics found. Try a clearer photo or enter the lyrics yourself.';
        });
        return;
      }

      var draft = createScannedSongDraft(recognizedText, aiFallback: true);
      var aiAvailable = false;
      String? aiMessage;
      OnDeviceAiStatus aiStatus;
      try {
        aiStatus = await service.getAiStatus();
      } catch (_) {
        aiStatus = OnDeviceAiStatus.unavailable;
      }
      if (aiStatus == OnDeviceAiStatus.downloadable) {
        final acceptedTerms = await _confirmGemmaTerms();
        if (!mounted) return;
        if (acceptedTerms) {
          setState(
            () => _scanProgress = 'Getting the song AI model from Google Play…',
          );
          try {
            await service.downloadAiModel();
            aiAvailable = true;
          } catch (error) {
            debugPrint('Could not get the Gemma asset pack: $error');
            aiMessage = 'Couldn’t prepare song AI. The OCR text is shown below; check it and add the title before saving.';
          }
        } else {
          aiMessage = 'AI setup was skipped. The OCR text is shown below; check it and add the title before saving.';
        }
      } else if (aiStatus == OnDeviceAiStatus.downloading) {
        setState(
          () => _scanProgress = 'Getting the song AI model from Google Play…',
        );
        try {
          await service.downloadAiModel();
          aiAvailable = true;
        } catch (error) {
          debugPrint('Could not get the Gemma asset pack: $error');
          aiMessage = 'Couldn’t prepare song AI. The OCR text is shown below; check it and add the title before saving.';
        }
      } else if (aiStatus == OnDeviceAiStatus.available) {
        aiAvailable = true;
      } else {
        aiMessage = 'Google Play couldn’t provide song AI. The OCR text is shown below; check it and add the title before saving.';
      }
      if (aiAvailable) {
        if (mounted) {
          setState(() => _scanProgress = 'Starting on-device AI…');
        }
        final progressSubscription = service.aiProgress.listen((progress) {
          if (mounted) setState(() => _scanProgress = progress);
        });
        try {
          draft = await service.structure(recognizedText);
        } catch (error) {
          debugPrint('On-device song structuring failed: $error');
          aiMessage = 'Couldn’t organize this song. The OCR text is shown below; check it and add the title before saving.';
        } finally {
          await progressSubscription.cancel();
        }
      }
      if (!mounted) return;
      setState(() {
        _titleController.text = draft.title;
        _englishTitleController.text = draft.englishTitle ?? '';
        _bodyController.text = draft.body;
        _englishBodyController.text = draft.englishBody ?? '';
        if (draft.author?.trim().isNotEmpty ?? false) {
          _authorController.text = draft.author!;
        }
        _draftIsScanned = true;
        _draftAiEnhanced = draft.aiEnhanced;
        _draftAiFallback = draft.aiFallback;
        _scanError = aiMessage;
        _detailsExpanded = true;
      });
      _scheduleDraftSave();
    } catch (error) {
      debugPrint('Song photo text recognition failed: $error');
      if (!mounted) return;
      setState(() {
        _scanError = 'Couldn’t read this photo. Try another image or enter the lyrics yourself.';
      });
    } finally {
      if (mounted) setState(() => _readingImage = false);
    }
  }

  Future<bool> _confirmGemmaTerms() async {
    var accepted = false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Get on-device song AI?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Google Play will download the Gemma model once (about 584 MB). It runs on this device; scanned text isn’t sent to a server. A Wi-Fi connection may be needed.',
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://ai.google.dev/gemma/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Gemma terms'),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://ai.google.dev/gemma/prohibited_use_policy',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Use policy'),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: (value) =>
                        setDialogState(() => accepted = value ?? false),
                    title: const Text(
                      'I agree to the Gemma Terms of Use and Prohibited Use Policy.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: accepted
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (widget.songId == null && !_draftCompleted) {
      unawaited(_persistDraft());
    }
    _titleController.dispose();
    _englishTitleController.dispose();
    _bodyController.dispose();
    _englishBodyController.dispose();
    _authorController.dispose();
    _maleVideoUrlController.dispose();
    _femaleVideoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    LocalSongDraft? draft;
    try {
      draft = await ref.read(localSongDraftStoreProvider).load();
    } catch (_) {
      draft = null;
    }
    if (!mounted) return;
    if (draft != null && !_draftChanged && !draft.isEmpty) {
      _titleController.text = draft.title;
      _englishTitleController.text = draft.englishTitle;
      _bodyController.text = draft.body;
      _englishBodyController.text = draft.englishBody;
      _authorController.text = draft.author;
      _maleVideoUrlController.text = draft.maleVideoUrl;
      _femaleVideoUrlController.text = draft.femaleVideoUrl;
      _newImagePath = draft.imagePath;
      _detailsExpanded = draft.detailsExpanded;
      _draftIsScanned = draft.isScanned;
      _draftAiEnhanced = draft.aiEnhanced;
      _draftAiFallback = draft.aiFallback;
      _draftRecovered = true;
    }
    final changedBeforeLoad = _draftChanged;
    setState(() => _draftLoading = false);
    if (changedBeforeLoad) _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    if (widget.songId != null || _draftCompleted) return;
    _draftChanged = true;
    if (_draftLoading) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_persistDraft()),
    );
  }

  Future<void> _persistDraft() async {
    if (widget.songId != null || _draftCompleted) return;
    if (_draftLoading && !_draftChanged) return;
    final draft = _draftSnapshot();
    try {
      await _draftInitialization;
      if (_draftCompleted) return;
      final store = ref.read(localSongDraftStoreProvider);
      final previous = await store.load();
      if (draft.isEmpty) {
        await store.clear();
      } else {
        await store.save(draft);
      }
      final previousImage = previous?.imagePath;
      if (previousImage != null && previousImage != draft.imagePath) {
        await LocalCustomSongImageStore().delete(previousImage);
      }
    } catch (_) {}
  }

  LocalSongDraft _draftSnapshot() => LocalSongDraft(
    title: _titleController.text,
    englishTitle: _englishTitleController.text,
    body: _bodyController.text,
    englishBody: _englishBodyController.text,
    author: _authorController.text,
    maleVideoUrl: _maleVideoUrlController.text,
    femaleVideoUrl: _femaleVideoUrlController.text,
    imagePath: _activeImagePath,
    detailsExpanded: _detailsExpanded,
    isScanned: _draftIsScanned,
    aiEnhanced: _draftAiEnhanced,
    aiFallback: _draftAiFallback,
  );

  Future<void> _saveIncomingDraft(ScannedSongDraft scannedDraft) async {
    try {
      final store = ref.read(localSongDraftStoreProvider);
      final previous = await store.load();
      await store.save(
        LocalSongDraft(
          title: scannedDraft.title,
          englishTitle: scannedDraft.englishTitle ?? '',
          body: scannedDraft.body,
          englishBody: scannedDraft.englishBody ?? '',
          author: scannedDraft.author ?? '',
          maleVideoUrl: '',
          femaleVideoUrl: '',
          imagePath: scannedDraft.imagePath,
          detailsExpanded: true,
          isScanned: scannedDraft.body.trim().isNotEmpty,
          aiEnhanced: scannedDraft.aiEnhanced,
          aiFallback: scannedDraft.aiFallback,
        ),
      );
      final previousImage = previous?.imagePath;
      if (previousImage != null && previousImage != scannedDraft.imagePath) {
        await LocalCustomSongImageStore().delete(previousImage);
      }
    } catch (_) {}
    if (!mounted) return;
    final changedWhileSaving = _draftChanged;
    setState(() => _draftLoading = false);
    if (changedWhileSaving) _scheduleDraftSave();
  }

  Future<void> _clearSavedDraft() async {
    try {
      await _draftInitialization;
      final store = ref.read(localSongDraftStoreProvider);
      final previous = await store.load();
      await store.clear();
      if (previous?.imagePath case final imagePath?) {
        await LocalCustomSongImageStore().delete(imagePath);
      }
    } catch (_) {}
  }

  Future<void> _discardDraft() async {
    _draftCompleted = true;
    _draftSaveTimer?.cancel();
    await _clearSavedDraft();
    if (!mounted) return;
    setState(() {
      _titleController.clear();
      _englishTitleController.clear();
      _bodyController.clear();
      _englishBodyController.clear();
      _authorController.clear();
      _maleVideoUrlController.clear();
      _femaleVideoUrlController.clear();
      _newImagePath = null;
      _draftRecovered = false;
      _draftChanged = false;
      _draftIsScanned = false;
      _draftAiEnhanced = false;
      _draftAiFallback = false;
      _detailsExpanded = false;
      _draftCompleted = false;
    });
  }

  Future<void> _save() async {
    if (_saving ||
        _draftLoading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);

    final input = SongInput(
      title: _titleController.text,
      englishTitle: _englishTitleController.text,
      body: _bodyController.text,
      englishBody: _englishBodyController.text,
      author: _authorController.text,
      maleVideoUrl: _maleVideoUrlController.text,
      femaleVideoUrl: _femaleVideoUrlController.text,
      newImagePath: _newImagePath,
      removeImage: _removeImage,
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      final id = widget.songId;
      final savedId = id ?? await repository.createCustomSong(input);
      if (id != null) await repository.updateCustomSong(id, input);
      if (!mounted) return;
      _draftCompleted = true;
      _draftSaveTimer?.cancel();
      await _clearSavedDraft();
      if (!mounted) return;
      if (id == null) {
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => AddToListSheet(songId: savedId),
        );
        if (!mounted) return;
      }
      context.go('/songs/$savedId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t save the song.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.songId;
    if (id == null) return _buildEditor();

    final song = ref.watch(songProvider(id));
    return song.when(
      data: (value) {
        if (value == null || value.source != 'custom') {
          return const _CustomSongUnavailable();
        }
        if (!_initialized) {
          _titleController.text = value.title;
          _englishTitleController.text = value.englishTitle ?? '';
          _bodyController.text = value.body;
          _englishBodyController.text = value.englishBody ?? '';
          _authorController.text = value.author ?? '';
          _maleVideoUrlController.text = value.maleVideoUrl ?? '';
          _femaleVideoUrlController.text = value.femaleVideoUrl ?? '';
          _existingImagePath = value.imagePath;
          _initialized = true;
        }
        return _buildEditor();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stackTrace) => const _CustomSongUnavailable(),
    );
  }

  Widget _buildEditor() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit song'
              : _draftIsScanned
              ? 'Review scanned lyrics'
              : 'Add a song',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (_draftRecovered) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Unfinished song recovered'),
                  subtitle: const Text('Continue where you left off.'),
                  trailing: TextButton(
                    onPressed: _discardDraft,
                    child: const Text('Discard'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_draftIsScanned) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _draftAiFallback
                      ? const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.warning_amber_rounded),
                          title: Text('Couldn’t identify a song'),
                          subtitle: Text(
                            'The OCR text is shown below. Add the title and '
                            'check the lyrics before saving.',
                          ),
                        )
                      : Text(_scanReviewMessage),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Song title',
                hintText: 'Enter the song title',
              ),
              textInputAction: TextInputAction.next,
              validator: _requiredValidator,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            const SizedBox(height: 16),
            if (_activeImagePath case final imagePath?) ...[
              _SongPhotoEditorCard(
                imagePath: imagePath,
                reading: _readingImage,
                progressLabel: _scanProgress,
                onRead: _readFromImage,
                onRemove: () => setState(() {
                  _newImagePath = null;
                  _removeImage = true;
                  _scheduleDraftSave();
                }),
              ),
              if (_scanError case final error?) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'Lyrics',
                hintText: _activeImagePath == null
                    ? 'Lyrics in the original language'
                    : 'Optional when keeping the original photo',
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  onPressed: _pasteLyrics,
                  tooltip: 'Paste lyrics',
                  icon: const Icon(Icons.content_paste_outlined),
                ),
              ),
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: _activeImagePath == null ? _requiredValidator : null,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _detailsExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _detailsExpanded = expanded);
                _scheduleDraftSave();
              },
              leading: const Icon(Icons.tune_outlined),
              title: const Text('More details'),
              subtitle: const Text('English title, lyrics, author, and videos'),
              children: [
                TextFormField(
                  controller: _englishTitleController,
                  decoration: const InputDecoration(
                    labelText: 'English title',
                    hintText: 'Optional',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _scheduleDraftSave(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _englishBodyController,
                  decoration: const InputDecoration(
                    labelText: 'English lyrics',
                    hintText: 'Optional',
                    alignLabelWithHint: true,
                  ),
                  minLines: 6,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => _scheduleDraftSave(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author or source',
                    hintText: 'Optional',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _scheduleDraftSave(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maleVideoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Male practice video',
                    hintText: 'Paste a YouTube link (optional)',
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: _optionalYoutubeValidator,
                  onChanged: (_) => _scheduleDraftSave(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _femaleVideoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Female practice video',
                    hintText: 'Paste a YouTube link (optional)',
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  validator: _optionalYoutubeValidator,
                  onChanged: (_) => _scheduleDraftSave(),
                  onFieldSubmitted: (_) => _save(),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save song'),
        ),
      ),
    );
  }

  static String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  static String? _optionalYoutubeValidator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.toLowerCase() ?? '';
    final isYoutube =
        host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
    return uri != null && uri.hasScheme && isYoutube
        ? null
        : 'Enter a valid YouTube link';
  }

  String get _scanReviewMessage {
    if (_draftAiEnhanced) {
      return 'The lyrics were organized on this device. Check every field and '
          'line break before saving.';
    }
    if (_activeImagePath != null) {
      return 'The original photo will be kept. Add a title and check the '
          'photo before saving.';
    }
    return 'Scanned text can contain mistakes. Check the title, line breaks, '
        'and lyrics before saving.';
  }

  String? get _activeImagePath {
    if (_newImagePath != null) return _newImagePath;
    return _removeImage ? null : _existingImagePath;
  }
}

class _SongPhotoEditorCard extends StatelessWidget {
  const _SongPhotoEditorCard({
    required this.imagePath,
    required this.reading,
    required this.progressLabel,
    required this.onRead,
    required this.onRemove,
  });

  final String imagePath;
  final bool reading;
  final String progressLabel;
  final VoidCallback onRead;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.broken_image_outlined, size: 42),
                    SizedBox(height: 10),
                    Text('Couldn’t open this photo.'),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Original photo'),
            trailing: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: reading ? null : onRead,
              icon: reading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(reading ? progressLabel : 'Read from image'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSongUnavailable extends StatelessWidget {
  const _CustomSongUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Custom song not found.')),
    );
  }
}
