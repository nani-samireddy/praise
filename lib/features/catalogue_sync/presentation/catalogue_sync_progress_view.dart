import 'package:flutter/material.dart';

import '../data/catalogue_sync_service.dart';

class CatalogueSyncProgressView extends StatelessWidget {
  const CatalogueSyncProgressView({
    required this.progress,
    this.compact = false,
    super.key,
  });

  final CatalogueSyncProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (progress.progress * 100).clamp(0, 100).round();

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(progress.message, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(width: 12),
              Text('$percentage%', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.progress),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    progress.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$percentage%', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.progress),
          ],
        ),
      ),
    );
  }
}
