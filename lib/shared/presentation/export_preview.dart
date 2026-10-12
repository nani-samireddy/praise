import 'package:flutter/material.dart';

Future<bool> confirmExportPreview(
  BuildContext context, {
  required String title,
  required String content,
  bool image = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview: $title'),
        content: SingleChildScrollView(
          child: Text(
            '$content${image ? '\n\nLong content may exceed the image limit. PDF supports multiple pages; choose PDF if image export is too long.' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to share'),
          ),
        ],
      ),
    ) ==
    true;

Rect? exportShareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  return Rect.fromCenter(center: center, width: 1, height: 1);
}
