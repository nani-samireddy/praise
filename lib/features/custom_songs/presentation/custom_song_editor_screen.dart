import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../songs/data/song_repository.dart';
import '../../songs/presentation/song_providers.dart';
import '../data/scanned_song_draft.dart';

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
  var _initialized = false;
  var _saving = false;

  bool get _isEditing => widget.songId != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.scannedDraft;
    if (widget.songId == null && draft != null) {
      _titleController.text = draft.title;
      _bodyController.text = draft.body;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _englishTitleController.dispose();
    _bodyController.dispose();
    _englishBodyController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final input = SongInput(
      title: _titleController.text,
      englishTitle: _englishTitleController.text,
      body: _bodyController.text,
      englishBody: _englishBodyController.text,
      author: _authorController.text,
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      final id = widget.songId;
      final savedId = id ?? await repository.createCustomSong(input);
      if (id != null) await repository.updateCustomSong(id, input);
      if (!mounted) return;
      context.go('/songs/$savedId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save the song.')));
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
              : widget.scannedDraft == null
              ? 'New song'
              : 'Review scanned song',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (widget.scannedDraft != null) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'OCR can make mistakes. Check the title, line breaks, and '
                    'lyrics before saving to My Songs.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Primary-language title',
              ),
              textInputAction: TextInputAction.next,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _englishTitleController,
              decoration: const InputDecoration(
                labelText: 'English title',
                hintText: 'Optional',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body',
                hintText: 'Primary-language lyrics',
                alignLabelWithHint: true,
              ),
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _englishBodyController,
              decoration: const InputDecoration(
                labelText: 'English body',
                hintText: 'Optional English lyrics',
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                hintText: 'Optional',
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
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
