import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scanned_song_draft.dart';
import '../data/song_scan_service.dart';

class ScanSongScreen extends ConsumerStatefulWidget {
  const ScanSongScreen({super.key});

  @override
  ConsumerState<ScanSongScreen> createState() => _ScanSongScreenState();
}

class _ScanSongScreenState extends ConsumerState<ScanSongScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  bool _recognizing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  Future<void> _recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (!mounted || response.isEmpty) return;
    final image = response.files?.firstOrNull;
    if (image != null) await _recognize(image);
  }

  Future<void> _pick(ImageSource source) async {
    if (_recognizing) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2400,
      );
      if (image != null) await _recognize(image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera or photo.');
    }
  }

  Future<void> _recognize(XFile image) async {
    setState(() {
      _image = image;
      _recognizing = true;
      _error = null;
    });
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
      context.pushReplacement(
        '/custom-song/new',
        extra: createScannedSongDraft(text),
      );
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
          if (_recognizing) ...[
            const Center(child: CircularProgressIndicator.adaptive()),
            const SizedBox(height: 14),
            const Text(
              'Reading Telugu and English text…',
              textAlign: TextAlign.center,
            ),
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.offline_bolt_outlined, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recognition happens on this device. The photo is not uploaded. '
                  'You can correct the title and lyrics before saving.',
                ),
              ),
            ],
          ),
        ],
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
              'Photograph printed lyrics or clear screen text',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'For the best result, use bright light, keep the page flat, and '
              'fill the frame with the text.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
