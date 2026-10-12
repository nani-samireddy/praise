import 'dart:io';

import 'package:flutter/material.dart';

class SongPhotoEditorCard extends StatelessWidget {
  const SongPhotoEditorCard({
    super.key,
    required this.imagePath,
    required this.onRemove,
  });

  final String imagePath;
  final VoidCallback? onRemove;

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
        ],
      ),
    );
  }
}
