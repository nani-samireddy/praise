import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/custom_song_image_store.dart';
import '../data/scanned_song_draft.dart';

class ScanSongScreen extends StatefulWidget {
  const ScanSongScreen({super.key});

  @override
  State<ScanSongScreen> createState() => _ScanSongScreenState();
}

class _ScanSongScreenState extends State<ScanSongScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  bool _recognizing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openGalleryOnEntry());
  }

  Future<void> _openGalleryOnEntry() async {
    final recoveredImage = await _recoverLostImage();
    if (!mounted || recoveredImage) return;
    await _pick(ImageSource.gallery);
  }

  Future<bool> _recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (!mounted || response.isEmpty) return false;
    final image = response.files?.firstOrNull;
    if (image == null) return false;
    await _process(image);
    return true;
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
      setState(() => _error = 'Couldn’t open the camera or photo.');
    }
  }

  Future<void> _process(XFile image) async {
    setState(() {
      _image = image;
      _recognizing = true;
      _error = null;
    });
    String? storedPath;
    try {
      storedPath = await LocalCustomSongImageStore().save(image.path);
      if (!mounted) {
        await LocalCustomSongImageStore().delete(storedPath);
        return;
      }
      context.pushReplacement(
        '/custom-song/new',
        extra: createPhotoSongDraft(storedPath),
      );
    } catch (_) {
      if (storedPath != null) {
        await LocalCustomSongImageStore().delete(storedPath);
      }
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _error = 'Couldn’t save this photo. Try another one.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add song from photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            if (_image case final image?) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Image.file(File(image.path), fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 72),
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Choose a song photo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a clear photo of the lyrics to add them to your songs.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
            ],
            if (_recognizing) ...[
              const Center(child: CircularProgressIndicator.adaptive()),
              const SizedBox(height: 14),
              const Text('Adding photo…', textAlign: TextAlign.center),
            ] else ...[
              FilledButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take a photo instead'),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            Text(
              'Your photo stays on this device. You can review everything before saving.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
