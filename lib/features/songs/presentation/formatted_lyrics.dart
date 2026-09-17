import 'package:flutter/material.dart';

import 'lyrics_document.dart';

class BilingualFormattedLyrics extends StatelessWidget {
  const BilingualFormattedLyrics({
    super.key,
    required this.primaryBody,
    required this.englishBody,
    required this.fontSize,
    this.primaryFontFamily,
    this.expandCounts = false,
  });

  final String primaryBody;
  final String englishBody;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final primaryBlocks = parseLyricsDocument(primaryBody);
    final englishBlocks = parseLyricsDocument(englishBody);
    final blockCount = primaryBlocks.length > englishBlocks.length
        ? primaryBlocks.length
        : englishBlocks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blockCount; index++) ...[
          if (index > 0)
            SizedBox(
              height: _spacingBetween(
                primaryBlocks.elementAtOrNull(index - 1) ??
                    englishBlocks.elementAtOrNull(index - 1),
                primaryBlocks.elementAtOrNull(index) ??
                    englishBlocks.elementAtOrNull(index),
              ),
            ),
          _BilingualBlockView(
            primary: primaryBlocks.elementAtOrNull(index),
            english: englishBlocks.elementAtOrNull(index),
            fontSize: fontSize,
            primaryFontFamily: primaryFontFamily,
            expandCounts: expandCounts,
          ),
        ],
      ],
    );
  }

  double _spacingBetween(LyricsBlock? previous, LyricsBlock? current) {
    if (previous?.type == LyricsBlockType.repeat) {
      return 30;
    }
    if (previous?.type == LyricsBlockType.repeatBlock) {
      return 32;
    }
    if (previous != null &&
        previous.type != LyricsBlockType.lyrics &&
        current?.type == LyricsBlockType.lyrics) {
      return 30;
    }
    return switch (current?.type) {
      LyricsBlockType.section => 24,
      LyricsBlockType.repeat => 18,
      LyricsBlockType.repeatBlock => 20,
      LyricsBlockType.lyrics => 20,
      null => 20,
    };
  }
}

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
    if (previous.type == LyricsBlockType.repeat) {
      return 30;
    }
    if (previous.type == LyricsBlockType.repeatBlock) {
      return 32;
    }
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

class _BilingualBlockView extends StatelessWidget {
  const _BilingualBlockView({
    required this.primary,
    required this.english,
    required this.fontSize,
    required this.primaryFontFamily,
    required this.expandCounts,
  });

  final LyricsBlock? primary;
  final LyricsBlock? english;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    if (primary == null) {
      return _LyricsBlockView(
        block: english!,
        fontSize: fontSize,
        fontFamily: null,
        expandCounts: expandCounts,
      );
    }
    if (english == null || primary!.type != english!.type) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LyricsBlockView(
            block: primary!,
            fontSize: fontSize,
            fontFamily: primaryFontFamily,
            expandCounts: expandCounts,
          ),
          if (english != null) ...[
            const SizedBox(height: 10),
            _LyricsBlockView(
              block: english!,
              fontSize: fontSize,
              fontFamily: null,
              expandCounts: expandCounts,
            ),
          ],
        ],
      );
    }

    return switch (primary!.type) {
      LyricsBlockType.lyrics => _BilingualLyricsLines(
        primaryText: primary!.text,
        englishText: english!.text,
        fontSize: fontSize,
        primaryFontFamily: primaryFontFamily,
        expandCounts: expandCounts,
      ),
      LyricsBlockType.repeatBlock => _BilingualRepeatBlock(
        primaryText: primary!.text,
        englishText: english!.text,
        repeatCount: primary!.repeatCount,
        fontSize: fontSize,
        primaryFontFamily: primaryFontFamily,
        expandCounts: expandCounts,
      ),
      LyricsBlockType.section || LyricsBlockType.repeat => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LyricsBlockView(
            block: primary!,
            fontSize: fontSize,
            fontFamily: primaryFontFamily,
            expandCounts: expandCounts,
          ),
          if (primary!.text != english!.text) ...[
            const SizedBox(height: 4),
            _LyricsBlockView(
              block: english!,
              fontSize: fontSize,
              fontFamily: null,
              expandCounts: expandCounts,
            ),
          ],
        ],
      ),
    };
  }
}

class _BilingualLyricsLines extends StatelessWidget {
  const _BilingualLyricsLines({
    required this.primaryText,
    required this.englishText,
    required this.fontSize,
    required this.primaryFontFamily,
    required this.expandCounts,
    this.expandLineCounts = true,
    this.showRepeatLabels = true,
  });

  final String primaryText;
  final String englishText;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;
  final bool expandLineCounts;
  final bool showRepeatLabels;

  @override
  Widget build(BuildContext context) {
    final primaryLines = primaryText.split('\n');
    final englishLines = englishText.split('\n');
    final lineCount = primaryLines.length > englishLines.length
        ? primaryLines.length
        : englishLines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lineCount; index++) ...[
          if (index > 0)
            SizedBox(
              height: _spacingBeforeLine(
                primaryLines.elementAtOrNull(index - 1),
                englishLines.elementAtOrNull(index - 1),
              ),
            ),
          _BilingualLinePair(
            primaryLine: index < primaryLines.length
                ? primaryLines[index]
                : null,
            englishLine: index < englishLines.length
                ? englishLines[index]
                : null,
            fontSize: fontSize,
            primaryFontFamily: primaryFontFamily,
            expandCounts: expandCounts,
            expandLineCounts: expandLineCounts,
            showRepeatLabels: showRepeatLabels,
          ),
        ],
      ],
    );
  }

  double _spacingBeforeLine(String? primaryLine, String? englishLine) {
    final previousRepeatCount = [
      parseRepeatableLyricsLine(primaryLine ?? '')?.repeatCount ?? 1,
      parseRepeatableLyricsLine(englishLine ?? '')?.repeatCount ?? 1,
    ].reduce((left, right) => left > right ? left : right);
    if (previousRepeatCount > 1) {
      return 30;
    }
    return 22;
  }
}

class _BilingualLinePair extends StatelessWidget {
  const _BilingualLinePair({
    required this.primaryLine,
    required this.englishLine,
    required this.fontSize,
    required this.primaryFontFamily,
    required this.expandCounts,
    required this.expandLineCounts,
    required this.showRepeatLabels,
  });

  final String? primaryLine;
  final String? englishLine;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;
  final bool expandLineCounts;
  final bool showRepeatLabels;

  @override
  Widget build(BuildContext context) {
    final primaryRepeatable = primaryLine == null
        ? null
        : parseRepeatableLyricsLine(primaryLine!);
    final englishRepeatable = englishLine == null
        ? null
        : parseRepeatableLyricsLine(englishLine!);
    final repeatCount = [
      primaryRepeatable?.repeatCount ?? 1,
      englishRepeatable?.repeatCount ?? 1,
    ].reduce((left, right) => left > right ? left : right);

    if (expandCounts && expandLineCounts && repeatCount > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < repeatCount; index++) ...[
            if (index > 0) SizedBox(height: fontSize * 0.85),
            _buildPlainPair(
              context: context,
              primaryText: primaryRepeatable?.text ?? primaryLine,
              englishText: englishRepeatable?.text ?? englishLine,
            ),
          ],
        ],
      );
    }

    return _buildAnnotatedPair(context: context);
  }

  Widget _buildAnnotatedPair({required BuildContext context}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primaryLine != null && primaryLine!.trim().isNotEmpty)
          _LyricsLine(
            line: primaryLine!,
            fontSize: fontSize,
            fontFamily: primaryFontFamily,
            expandCount: false,
            addExpandedBottomSpacing: false,
            showRepeatLabel: showRepeatLabels,
          ),
        if (englishLine != null && englishLine!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _LyricsLine(
              line: englishLine!,
              fontSize: fontSize * 0.9,
              fontFamily: null,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              expandCount: false,
              addExpandedBottomSpacing: false,
              showRepeatLabel: showRepeatLabels,
            ),
          ),
      ],
    );
  }

  Widget _buildPlainPair({
    required BuildContext context,
    required String? primaryText,
    required String? englishText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primaryText != null && primaryText.trim().isNotEmpty)
          Text(
            primaryText,
            style: TextStyle(
              fontFamily: primaryFontFamily,
              fontSize: fontSize,
              height: 1.6,
            ),
          ),
        if (englishText != null && englishText.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              englishText,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                height: 1.55,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _BilingualRepeatBlock extends StatelessWidget {
  const _BilingualRepeatBlock({
    required this.primaryText,
    required this.englishText,
    required this.repeatCount,
    required this.fontSize,
    required this.primaryFontFamily,
    required this.expandCounts,
  });

  final String primaryText;
  final String englishText;
  final int repeatCount;
  final double fontSize;
  final String? primaryFontFamily;
  final bool expandCounts;

  @override
  Widget build(BuildContext context) {
    final content = _BilingualLyricsLines(
      primaryText: primaryText,
      englishText: englishText,
      fontSize: fontSize,
      primaryFontFamily: primaryFontFamily,
      expandCounts: expandCounts,
      expandLineCounts: !expandCounts,
      showRepeatLabels: !expandCounts,
    );
    if (expandCounts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < repeatCount; index++) ...[
            if (index > 0) SizedBox(height: fontSize * 0.85),
            content,
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const SizedBox(height: 10),
        _RepeatCountLabel(
          repeatCount: repeatCount,
          fontSize: fontSize,
          fontFamily: primaryFontFamily,
        ),
      ],
    );
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
        const SizedBox(height: 10),
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
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _LyricsLine(
            line: lines[index],
            fontSize: fontSize,
            fontFamily: fontFamily,
            expandCount: expandCounts,
            addExpandedBottomSpacing: index < lastContentIndex,
            addRepeatBottomSpacing: index < lastContentIndex,
          ),
        ],
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
    this.addRepeatBottomSpacing = false,
    this.showRepeatLabel = true,
    this.color,
  });

  final String line;
  final double fontSize;
  final String? fontFamily;
  final bool expandCount;
  final bool addExpandedBottomSpacing;
  final bool addRepeatBottomSpacing;
  final bool showRepeatLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final repeatable = parseRepeatableLyricsLine(line);
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: 1.6,
      color: color,
    );
    if (repeatable == null) return Text(line, style: style);

    final countLabel = _RepeatCountLabel(
      repeatCount: repeatable.repeatCount,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );

    if (!expandCount) {
      final annotatedLine = Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(repeatable.text, style: style),
          if (showRepeatLabel) countLabel,
        ],
      );
      return addRepeatBottomSpacing
          ? Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: annotatedLine,
            )
          : annotatedLine;
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
