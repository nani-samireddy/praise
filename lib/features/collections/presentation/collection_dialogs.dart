import 'package:flutter/material.dart';

Future<String?> showCollectionNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'List name'),
          textCapitalization: TextCapitalization.words,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'List name is required'
              : null,
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> confirmCollectionDeletion(
  BuildContext context,
  String name,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete list?'),
          content: Text('"$name" will be deleted. Its songs will remain safe.'),
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
      ) ??
      false;
}
