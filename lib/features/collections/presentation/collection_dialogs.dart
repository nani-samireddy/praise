import 'package:flutter/material.dart';

Future<String?> showCollectionNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _CollectionNameDialog(title: title, initialValue: initialValue),
  );
}

class _CollectionNameDialog extends StatefulWidget {
  const _CollectionNameDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final String initialValue;

  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'List name'),
          textCapitalization: TextCapitalization.words,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'List name is required'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
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
