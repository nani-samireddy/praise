import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/lyrics_document.dart';

void main() {
  test('parses lyric groups, section labels, and repeat cues', () {
    final blocks = parseLyricsDocument('''
[Verse 1]
First line ×2
Second line

[Repeat: Agni]

[Chorus]
Chorus line
''');

    expect(blocks.map((block) => block.type), [
      LyricsBlockType.section,
      LyricsBlockType.lyrics,
      LyricsBlockType.repeat,
      LyricsBlockType.section,
      LyricsBlockType.lyrics,
    ]);
    expect(blocks[1].text, 'First line ×2\nSecond line');
    expect(blocks[2].text, 'Agni');
  });

  test('leaves unknown bracketed text as lyrics', () {
    final blocks = parseLyricsDocument('[Spoken]\nRead this line');

    expect(blocks, hasLength(1));
    expect(blocks.single.type, LyricsBlockType.lyrics);
    expect(blocks.single.text, '[Spoken]\nRead this line');
  });

  test('parses a safe trailing repeat annotation', () {
    final line = parseRepeatableLyricsLine('Sing this line ×4');

    expect(line?.text, 'Sing this line');
    expect(line?.repeatCount, 4);
    expect(parseRepeatableLyricsLine('×2 at the start'), isNull);
    expect(parseRepeatableLyricsLine('Untrusted count ×999'), isNull);
  });

  test('parses a safe multi-line repeat block', () {
    final blocks = parseLyricsDocument('''
[Chorus]
[Repeat ×2]
Line one
Line two
[/Repeat]

Next line
''');

    expect(blocks.map((block) => block.type), [
      LyricsBlockType.section,
      LyricsBlockType.repeatBlock,
      LyricsBlockType.lyrics,
    ]);
    expect(blocks[1].text, 'Line one\nLine two');
    expect(blocks[1].repeatCount, 2);
  });

  test('leaves an unclosed repeat block as lyrics', () {
    final blocks = parseLyricsDocument('''
[Repeat ×2]
Line one
Line two
''');

    expect(blocks, hasLength(1));
    expect(blocks.single.type, LyricsBlockType.lyrics);
    expect(blocks.single.text, '[Repeat ×2]\nLine one\nLine two');
  });
}
