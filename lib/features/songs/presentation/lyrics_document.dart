enum LyricsBlockType { lyrics, section, repeat, repeatBlock }

class LyricsBlock {
  const LyricsBlock({
    required this.type,
    required this.text,
    this.repeatCount = 1,
  });

  final LyricsBlockType type;
  final String text;
  final int repeatCount;
}

class RepeatableLyricsLine {
  const RepeatableLyricsLine({required this.text, required this.repeatCount});

  final String text;
  final int repeatCount;
}

final _repeatPattern = RegExp(r'^\[Repeat:\s*(.+)\]$', caseSensitive: false);
final _repeatBlockStartPattern = RegExp(
  r'^\[Repeat\s*(?:×|x)\s*([2-9]|1[0-2])\]$',
  caseSensitive: false,
);
final _repeatBlockEndPattern = RegExp(r'^\[/Repeat\]$', caseSensitive: false);
final _sectionPattern = RegExp(
  r'^\[(Verse(?:\s+\d+)?|Chorus|Pre-Chorus|Bridge|Ending)\]$',
  caseSensitive: false,
);
final _lineRepeatPattern = RegExp(r'^(.+?)\s+×(\d+)\s*$');

RepeatableLyricsLine? parseRepeatableLyricsLine(String line) {
  final match = _lineRepeatPattern.firstMatch(line);
  if (match == null) return null;
  final repeatCount = int.tryParse(match.group(2)!);
  if (repeatCount == null || repeatCount < 2 || repeatCount > 12) return null;
  return RepeatableLyricsLine(
    text: match.group(1)!.trimRight(),
    repeatCount: repeatCount,
  );
}

List<LyricsBlock> parseLyricsDocument(String body) {
  final blocks = <LyricsBlock>[];
  final lyricLines = <String>[];
  List<String>? repeatBlockLines;
  var repeatBlockCount = 1;

  void flushLyrics() {
    if (lyricLines.isEmpty) return;
    blocks.add(
      LyricsBlock(type: LyricsBlockType.lyrics, text: lyricLines.join('\n')),
    );
    lyricLines.clear();
  }

  void flushRepeatBlockAsLyrics() {
    final lines = repeatBlockLines;
    if (lines == null) return;
    _trimTrailingBlankLines(lines);
    lyricLines
      ..add('[Repeat ×$repeatBlockCount]')
      ..addAll(lines);
    repeatBlockLines = null;
    repeatBlockCount = 1;
  }

  for (final rawLine in body.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trim();
    final activeRepeatBlockLines = repeatBlockLines;
    if (activeRepeatBlockLines != null) {
      if (_repeatBlockEndPattern.hasMatch(line)) {
        _trimTrailingBlankLines(activeRepeatBlockLines);
        blocks.add(
          LyricsBlock(
            type: LyricsBlockType.repeatBlock,
            text: activeRepeatBlockLines.join('\n'),
            repeatCount: repeatBlockCount,
          ),
        );
        repeatBlockLines = null;
        repeatBlockCount = 1;
      } else {
        activeRepeatBlockLines.add(rawLine.trimRight());
      }
      continue;
    }

    if (line.isEmpty) {
      flushLyrics();
      continue;
    }
    final repeatBlockStartMatch = _repeatBlockStartPattern.firstMatch(line);
    if (repeatBlockStartMatch != null) {
      flushLyrics();
      repeatBlockLines = <String>[];
      repeatBlockCount = int.parse(repeatBlockStartMatch.group(1)!);
      continue;
    }
    final repeatMatch = _repeatPattern.firstMatch(line);
    if (repeatMatch != null) {
      flushLyrics();
      blocks.add(
        LyricsBlock(
          type: LyricsBlockType.repeat,
          text: repeatMatch.group(1)!.trim(),
        ),
      );
      continue;
    }
    final sectionMatch = _sectionPattern.firstMatch(line);
    if (sectionMatch != null) {
      flushLyrics();
      blocks.add(
        LyricsBlock(
          type: LyricsBlockType.section,
          text: sectionMatch.group(1)!.trim(),
        ),
      );
      continue;
    }
    lyricLines.add(rawLine.trimRight());
  }
  flushRepeatBlockAsLyrics();
  flushLyrics();
  return blocks;
}

void _trimTrailingBlankLines(List<String> lines) {
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
}
