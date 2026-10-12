import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../collections/presentation/add_to_list_sheet.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/presentation/song_providers.dart';
import '../data/local_song_draft.dart';
import '../data/scanned_song_draft.dart';
import '../data/song_scan_service.dart';
import 'song_photo_editor_card.dart';

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
  var _editDraftChecked = false;
  var _saving = false;
  var _leaving = false;
  var _draftError = false;
  var _songUnavailable = false;
  var _songChanged = false;
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
  Future<void>? _draftInitialization;
  String? _newImagePath;
  String? _existingImagePath;
  var _removeImage = false;

  late LocalSongDraftStore _draftStore;
  String? _baseUpdatedAt;
  Future<void> _draftWrites = Future.value();

  bool get _isEditing => widget.songId != null;

  @override
  void initState() {
    super.initState();
    _draftStore = ref.read(localSongDraftStoreProvider);
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
    if (imagePath == null || _readingImage || _saving || _draftLoading) return;
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
          unawaited(progressSubscription.cancel());
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
    if (!_draftCompleted && _draftChanged) {
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
      draft = await _draftStore.load(songId: widget.songId);
    } catch (_) {
      _draftError = true;
      draft = null;
    }
    if (!mounted) return;
    if (draft != null && !_draftChanged && !draft.isEmpty) {
      if (_isEditing) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore unfinished edits?'),
            content: const Text(
              'Restore the local draft or discard it to use the saved song. If the saved song changed, saving this draft will be blocked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (restore != true) {
          await _draftStore.clear(songId: widget.songId);
          await _draftStore.deleteUnreferencedImage(draft.imagePath);
          _initialized = false;
          setState(() => _draftLoading = false);
          return;
        }
        _baseUpdatedAt = draft.baseUpdatedAt;
        _removeImage = draft.imagePath == null;
      }
      _newImagePath = draft.imagePath == _existingImagePath
          ? null
          : draft.imagePath;
      _titleController.text = draft.title;
      _englishTitleController.text = draft.englishTitle;
      _bodyController.text = draft.body;
      _englishBodyController.text = draft.englishBody;
      _authorController.text = draft.author;
      _maleVideoUrlController.text = draft.maleVideoUrl;
      _femaleVideoUrlController.text = draft.femaleVideoUrl;
      _newImagePath = draft.imagePath == _existingImagePath
          ? null
          : draft.imagePath;
      _detailsExpanded = draft.detailsExpanded;
      _draftIsScanned = draft.isScanned;
      _draftAiEnhanced = draft.aiEnhanced;
      _draftAiFallback = draft.aiFallback;
      _draftRecovered = true;
      _initialized = true;
    }
    final changedBeforeLoad = _draftChanged;
    setState(() => _draftLoading = false);
    if (changedBeforeLoad) _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    if (_draftCompleted || _saving) return;
    setState(() => _draftChanged = true);
    if (_draftLoading) return;
    unawaited(_persistDraft());
  }

  Future<void> _persistDraft() {
    final snapshot = _draftSnapshot();
    _draftWrites = _draftWrites.then((_) => _writeDraft(snapshot));
    return _draftWrites;
  }

  Future<void> _writeDraft(LocalSongDraft draft) async {
    if (_draftCompleted) return;
    if (_draftLoading && !_draftChanged) return;
    try {
      await _draftInitialization;
      if (_draftCompleted) return;
      final store = _draftStore;
      final previous = await store.load(songId: widget.songId);
      if (draft.isEmpty) {
        await store.clear(songId: widget.songId);
      } else {
        await store.save(draft, songId: widget.songId);
      }
      _draftError = false;
      final previousImage = previous?.imagePath;
      if (previousImage != null && previousImage != draft.imagePath) {
        await store.deleteUnreferencedImage(previousImage);
      }
    } catch (_) {
      _draftError = true;
      if (mounted) setState(() {});
    }
  }

  LocalSongDraft _draftSnapshot() => LocalSongDraft(
    baseUpdatedAt: _baseUpdatedAt,
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
      final store = _draftStore;
      final previous = await store.load(songId: widget.songId);
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
        await store.deleteUnreferencedImage(previousImage);
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
      await _draftWrites;
      final store = _draftStore;
      final previous = await store.load(songId: widget.songId);
      await store.clear(songId: widget.songId);
      if (previous?.imagePath case final imagePath?) {
        await store.deleteUnreferencedImage(imagePath);
      }
    } catch (_) {}
  }

  Future<void> _discardDraft() async {
    final image = _activeImagePath;
    _draftCompleted = true;
    await _clearSavedDraft();
    await _draftStore.deleteUnreferencedImage(image);
    if (!mounted) return;
    setState(() {
      if (_isEditing) {
        _initialized = false;
        _newImagePath = null;
        _removeImage = false;
        _draftRecovered = false;
        _draftChanged = false;
        _draftCompleted = false;
        return;
      }
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
    if (_isEditing && _baseUpdatedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This draft has no saved revision. Reopen and discard it before editing the saved song.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await _persistDraft();
    if (!mounted) return;

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
      expectedUpdatedAt: _baseUpdatedAt == null
          ? null
          : DateTime.parse(_baseUpdatedAt!),
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      final id = widget.songId;
      final savedId = id ?? await repository.createCustomSong(input);
      if (id != null) await repository.updateCustomSong(id, input);
      if (!mounted) return;
      _draftCompleted = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn’t save. The song may have changed or been deleted. Your draft is kept; reopen the editor to review it.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.songId;
    if (id == null) return _buildEditor();

    final song = ref.watch(songProvider(id));
    return song.when(
      data: (value) {
        _songUnavailable = value == null || value.source != 'custom';
        _songChanged =
            value != null &&
            _baseUpdatedAt != null &&
            value.updatedAt.toIso8601String() != _baseUpdatedAt;
        if (_songUnavailable) {
          if (_initialized) return _buildEditor();
          if (!_editDraftChecked) {
            _editDraftChecked = true;
            _draftLoading = true;
            _draftInitialization = Future<void>(() => _loadDraft());
          }
          if (_draftRecovered) return _buildEditor();
          return const _CustomSongUnavailable();
        }
        if (!_initialized) {
          _titleController.text = value!.title;
          _englishTitleController.text = value.englishTitle ?? '';
          _bodyController.text = value.body;
          _englishBodyController.text = value.englishBody ?? '';
          _authorController.text = value.author ?? '';
          _maleVideoUrlController.text = value.maleVideoUrl ?? '';
          _femaleVideoUrlController.text = value.femaleVideoUrl ?? '';
          _existingImagePath = value.imagePath;
          _baseUpdatedAt = value.updatedAt.toIso8601String();
          _initialized = true;
          if (!_editDraftChecked) {
            _editDraftChecked = true;
            _draftLoading = true;
            _draftInitialization = Future<void>(() => _loadDraft());
          }
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
    return PopScope(
      canPop:
          _leaving ||
          _draftCompleted ||
          (!_draftChanged && !_saving && !_readingImage),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving || _readingImage) return;
        await _persistDraft();
        if (!mounted) return;
        if (_draftError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Couldn’t keep your draft. Try saving before leaving.',
              ),
            ),
          );
          return;
        }
        setState(() => _leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
      child: Scaffold(
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
              if (_songUnavailable || _songChanged)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _songUnavailable
                          ? 'The saved song was deleted. Your draft is kept here, but cannot overwrite a deleted song.'
                          : 'The saved song changed. Your draft is kept; reopen and discard it to use the latest saved version.',
                    ),
                  ),
                ),
              if (_draftError)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Couldn’t keep your draft. Save the song before leaving.',
                    ),
                  ),
                ),
              if (_draftRecovered) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('Unfinished song recovered'),
                    subtitle: const Text('Continue where you left off.'),
                    trailing: TextButton(
                      onPressed: _saving || _readingImage
                          ? null
                          : _discardDraft,
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
                enabled: !_saving && !_draftLoading && !_readingImage,
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
                SongPhotoEditorCard(
                  imagePath: imagePath,
                  reading: _readingImage,
                  progressLabel: _scanProgress,
                  onRead: _readFromImage,
                  onRemove: _readingImage || _saving || _draftLoading
                      ? null
                      : () => setState(() {
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
                enabled: !_saving && !_draftLoading && !_readingImage,
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
                subtitle: const Text(
                  'English title, lyrics, author, and videos',
                ),
                children: [
                  TextFormField(
                    enabled: !_saving && !_draftLoading && !_readingImage,
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
                    enabled: !_saving && !_draftLoading && !_readingImage,
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
                    enabled: !_saving && !_draftLoading && !_readingImage,
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
                    enabled: !_saving && !_draftLoading && !_readingImage,
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
                    enabled: !_saving && !_draftLoading && !_readingImage,
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
            onPressed:
                _saving || _readingImage || _draftLoading || _songUnavailable
                ? null
                : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save song'),
          ),
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
