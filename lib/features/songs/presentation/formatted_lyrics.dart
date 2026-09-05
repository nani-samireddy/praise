import 'package:flutter/material.dart';

import 'lyrics_document.dart';

class FormattedLyrics extends StatelessWidget {
  const FormattedLyrics({
    super.key,
    required this.body,
    required this.fontSize,
    this.fontFamily,
    this.expandCounts = false,
  });

  final String body;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final blocks = parseLyricsDocument(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0)
            SizedBox(height: _spacingBetween(blocks[index - 1], blocks[index])),
          _LyricsBlockView(
            block: blocks[index],
            fontSize: fontSize,
            fontFamily: fontFamily,
            expandCounts: expandCounts,
          ),
        ],
      ],
    );
  }

  double _spacingBetween(LyricsBlock previous, LyricsBlock current) {
    if (previous.type != LyricsBlockType.lyrics &&
        current.type == LyricsBlockType.lyrics) {
      return 30;
    }
    return switch (current.type) {
      LyricsBlockType.section => 24,
      LyricsBlockType.repeat => 18,
      LyricsBlockType.repeatBlock => 20,
      LyricsBlockType.lyrics => 20,
    };
  }
}

class _LyricsBlockView extends StatelessWidget {
  const _LyricsBlockView({
    required this.block,
    required this.fontSize,
    required this.fontFamily,
    required this.expandCounts,
  });

  final LyricsBlock block;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return switch (block.type) {
      LyricsBlockType.lyrics => _LyricsLines(
        text: block.text,
        fontSize: fontSize,
        fontFamily: fontFamily,
        expandCounts: expandCounts,
      ),
      LyricsBlockType.section => Text(
        block.text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontFamily: fontFamily,
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
              fontSize: (fontSize * 0.72).clamp(12, 24),
              fontFamily: fontFamily,
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      LyricsBlockType.repeatBlock => _RepeatBlockView(
        text: block.text,
        repeatCount: block.repeatCount,
        fontSize: fontSize,
        fontFamily: fontFamily,
        expandCounts: expandCounts,
      ),
    };
  }
}

class _RepeatBlockView extends StatelessWidget {
  const _RepeatBlockView({
    required this.text,
    required this.repeatCount,
    required this.fontSize,
    required this.fontFamily,
    required this.expandCounts,
  });

  final String text;
  final int repeatCount;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    if (expandCounts) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < repeatCount; index++) ...[
              if (index > 0) SizedBox(height: fontSize * 0.85),
              _LyricsLines(
                text: text,
                fontSize: fontSize,
                fontFamily: fontFamily,
                expandCounts: expandCounts,
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LyricsLines(
          text: text,
          fontSize: fontSize,
          fontFamily: fontFamily,
          expandCounts: expandCounts,
        ),
        const SizedBox(height: 6),
        _RepeatCountLabel(
          repeatCount: repeatCount,
          fontSize: fontSize,
          fontFamily: fontFamily,
        ),
      ],
    );
  }
}

class _LyricsLines extends StatelessWidget {
  const _LyricsLines({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.expandCounts,
  });

  final String text;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final lastContentIndex = lines.lastIndexWhere(
      (line) => line.trim().isNotEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++)
          _LyricsLine(
            line: lines[index],
            fontSize: fontSize,
            fontFamily: fontFamily,
            expandCount: expandCounts,
            addExpandedBottomSpacing: index < lastContentIndex,
          ),
      ],
    );
  }
}

class _LyricsLine extends StatelessWidget {
  const _LyricsLine({
    required this.line,
    required this.fontSize,
    required this.fontFamily,
    required this.expandCount,
    required this.addExpandedBottomSpacing,
  });

  final String line;
  final double fontSize;
  final String? fontFamily;
  final bool expandCount;
  final bool addExpandedBottomSpacing;

  @override
  Widget build(BuildContext context) {
    final repeatable = parseRepeatableLyricsLine(line);
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontSize: fontSize, fontFamily: fontFamily, height: 1.5);
    if (repeatable == null) return Text(line, style: style);

    final countLabel = _RepeatCountLabel(
      repeatCount: repeatable.repeatCount,
      fontSize: fontSize,
      fontFamily: fontFamily,
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
      padding: EdgeInsets.only(
        top: 4,
        bottom: addExpandedBottomSpacing ? 18 : 4,
      ),
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

class _RepeatCountLabel extends StatelessWidget {
  const _RepeatCountLabel({
    required this.repeatCount,
    required this.fontSize,
    required this.fontFamily,
  });

  final int repeatCount;
  final double fontSize;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          '×$repeatCount',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: (fontSize * 0.72).clamp(12, 24),
            fontFamily: fontFamily,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
