import 'package:flutter/material.dart';

import 'lyrics_document.dart';

class FormattedLyrics extends StatelessWidget {
  const FormattedLyrics({
    super.key,
    required this.body,
    required this.fontSize,
    this.expandCounts = false,
  });

  final String body;
  final double fontSize;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final blocks = parseLyricsDocument(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) SizedBox(height: _spacingBefore(blocks[index])),
          _LyricsBlockView(
            block: blocks[index],
            fontSize: fontSize,
            expandCounts: expandCounts,
          ),
        ],
      ],
    );
  }

  double _spacingBefore(LyricsBlock block) {
    return switch (block.type) {
      LyricsBlockType.section => 24,
      LyricsBlockType.repeat => 18,
      LyricsBlockType.lyrics => 20,
    };
  }
}

class _LyricsBlockView extends StatelessWidget {
  const _LyricsBlockView({
    required this.block,
    required this.fontSize,
    required this.expandCounts,
  });

  final LyricsBlock block;
  final double fontSize;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return switch (block.type) {
      LyricsBlockType.lyrics => _LyricsLines(
        text: block.text,
        fontSize: fontSize,
        expandCounts: expandCounts,
      ),
      LyricsBlockType.section => Text(
        block.text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      LyricsBlockType.repeat => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            block.text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    };
  }
}

class _LyricsLines extends StatelessWidget {
  const _LyricsLines({
    required this.text,
    required this.fontSize,
    required this.expandCounts,
  });

  final String text;
  final double fontSize;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in text.split('\n'))
          _LyricsLine(
            line: line,
            fontSize: fontSize,
            expandCount: expandCounts,
          ),
      ],
    );
  }
}

class _LyricsLine extends StatelessWidget {
  const _LyricsLine({
    required this.line,
    required this.fontSize,
    required this.expandCount,
  });

  final String line;
  final double fontSize;
  final bool expandCount;

  @override
  Widget build(BuildContext context) {
    final repeatable = parseRepeatableLyricsLine(line);
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontSize: fontSize, height: 1.5);
    if (repeatable == null) return Text(line, style: style);

    final countLabel = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          '×${repeatable.repeatCount}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    if (!expandCount) {
      return Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(repeatable.text, style: style),
          countLabel,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < repeatable.repeatCount; index++)
            Text(repeatable.text, style: style),
        ],
      ),
    );
  }
}
