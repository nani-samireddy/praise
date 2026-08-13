enum LyricsBlockType { lyrics, section, repeat }

class LyricsBlock {
  const LyricsBlock({required this.type, required this.text});

  final LyricsBlockType type;
  final String text;
}

class RepeatableLyricsLine {
  const RepeatableLyricsLine({required this.text, required this.repeatCount});

  final String text;
  final int repeatCount;
}

final _repeatPattern = RegExp(r'^\[Repeat:\s*(.+)\]$', caseSensitive: false);
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

  void flushLyrics() {
    if (lyricLines.isEmpty) return;
    blocks.add(
      LyricsBlock(type: LyricsBlockType.lyrics, text: lyricLines.join('\n')),
    );
    lyricLines.clear();
  }

  for (final rawLine in body.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushLyrics();
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
  flushLyrics();
  return blocks;
}
