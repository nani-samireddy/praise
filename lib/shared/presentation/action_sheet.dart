import 'package:flutter/material.dart';

class ActionSheetItem<T> {
  const ActionSheetItem({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String? subtitle;
}

Future<T?> showActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<ActionSheetItem<T>> items,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        subtitle: item.subtitle == null
                            ? null
                            : Text(item.subtitle!),
                        trailing: const Icon(Icons.chevron_right),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onTap: () => Navigator.pop(sheetContext, item.value),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
