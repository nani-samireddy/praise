import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scanned_song_draft.dart';
import '../data/song_scan_service.dart';

enum _ScanResultType { extractText, keepPhoto }

class ScanSongScreen extends ConsumerStatefulWidget {
  const ScanSongScreen({super.key});

  @override
  ConsumerState<ScanSongScreen> createState() => _ScanSongScreenState();
}

class _ScanSongScreenState extends ConsumerState<ScanSongScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  bool _recognizing = false;
  bool _checkingAi = true;
  bool _useAi = false;
  var _resultType = _ScanResultType.extractText;
  OnDeviceAiStatus _aiStatus = OnDeviceAiStatus.unavailable;
  String _progressMessage = 'Reading Telugu and English text…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
    _checkAiStatus();
  }

  Future<void> _checkAiStatus() async {
    final status = await ref.read(songScanServiceProvider).getAiStatus();
    if (!mounted) return;
    setState(() {
      _aiStatus = status;
      _checkingAi = false;
      _useAi = status != OnDeviceAiStatus.unavailable;
    });
  }

  Future<void> _recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (!mounted || response.isEmpty) return;
    final image = response.files?.firstOrNull;
    if (image != null) await _process(image);
  }

  Future<void> _pick(ImageSource source) async {
    if (_recognizing) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2400,
      );
      if (image != null) await _process(image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera or photo.');
    }
  }

  Future<void> _process(XFile image) async {
    setState(() {
      _image = image;
      _recognizing = _resultType == _ScanResultType.extractText;
      _progressMessage = 'Reading Telugu and English text…';
      _error = null;
    });
    if (_resultType == _ScanResultType.keepPhoto) {
      context.pushReplacement(
        '/custom-song/new',
        extra: createPhotoSongDraft(image.path),
      );
      return;
    }
    try {
      final text = await ref
          .read(songScanServiceProvider)
          .recognize(image.path);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() {
          _recognizing = false;
          _error = 'No readable Telugu or English text was found.';
        });
        return;
      }
      var draft = createScannedSongDraft(text);
      if (_useAi && _aiStatus != OnDeviceAiStatus.unavailable) {
        setState(
          () => _progressMessage = 'Organizing the song on this device…',
        );
        try {
          draft = await ref.read(songScanServiceProvider).structure(text);
        } catch (_) {
          draft = createScannedSongDraft(text, aiFallback: true);
        }
      }
      if (!mounted) return;
      context.pushReplacement('/custom-song/new', extra: draft);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _error = 'Text recognition failed. Try a clearer, straighter photo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan song')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_image == null)
            const _ScanInstructions()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.file(File(_image!.path), fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: 24),
          SegmentedButton<_ScanResultType>(
            segments: const [
              ButtonSegment(
                value: _ScanResultType.extractText,
                icon: Icon(Icons.text_snippet_outlined),
                label: Text('Extract text'),
              ),
              ButtonSegment(
                value: _ScanResultType.keepPhoto,
                icon: Icon(Icons.image_outlined),
                label: Text('Keep photo'),
              ),
            ],
            selected: {_resultType},
            onSelectionChanged: _recognizing
                ? null
                : (selection) => setState(() => _resultType = selection.single),
          ),
          const SizedBox(height: 20),
          if (_resultType == _ScanResultType.extractText)
            _AiOrganizationOption(
              checking: _checkingAi,
              status: _aiStatus,
              enabled: _useAi,
              onChanged: _recognizing || _checkingAi
                  ? null
                  : (value) => setState(() => _useAi = value),
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.photo_outlined),
                title: Text('Save the original photo'),
                subtitle: Text(
                  'No OCR is used. Add a title, then the photo will be kept '
                  'privately inside Praise.',
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_recognizing) ...[
            const Center(child: CircularProgressIndicator.adaptive()),
            const SizedBox(height: 14),
            Text(_progressMessage, textAlign: TextAlign.center),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 20),
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
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.offline_bolt_outlined, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  _resultType == _ScanResultType.extractText
                      ? 'Recognition happens on this device. The photo is not uploaded. '
                            'You can correct the title and lyrics before saving.'
                      : 'The photo stays on this device and is not uploaded. It is '
                            'copied into Praise only when you save the song.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiOrganizationOption extends StatelessWidget {
  const _AiOrganizationOption({
    required this.checking,
    required this.status,
    required this.enabled,
    required this.onChanged,
  });

  final bool checking;
  final OnDeviceAiStatus status;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final unavailable = !checking && status == OnDeviceAiStatus.unavailable;
    final subtitle = switch (status) {
      OnDeviceAiStatus.available => 'Gemini Nano will separate the title, lyrics, English text, and author.',
      OnDeviceAiStatus.downloadable =>
        'A one-time on-device model download is needed before the first scan.',
      OnDeviceAiStatus.downloading =>
        'The on-device model is currently downloading.',
      OnDeviceAiStatus.unavailable =>
        checking ? 'Checking whether Gemini Nano is available…' : 'Unavailable on this device. Regular offline OCR will still work.',
    };
    return Card(
      child: SwitchListTile.adaptive(
        value: unavailable ? false : enabled,
        onChanged: unavailable ? null : onChanged,
        secondary: const Icon(Icons.auto_awesome_outlined),
        title: const Text('Organize with on-device AI'),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _ScanInstructions extends StatelessWidget {
  const _ScanInstructions();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Photograph lyrics or choose an existing photo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Extract its text with offline OCR, or keep the original photo '
              'when OCR may not be reliable.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
