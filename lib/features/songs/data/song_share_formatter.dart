import '../presentation/lyrics_document.dart';

String formatLyricsForSharing(String body) {
  return parseLyricsDocument(body)
      .map((block) {
        return switch (block.type) {
          LyricsBlockType.lyrics => block.text,
          LyricsBlockType.section => '[${block.text}]',
          LyricsBlockType.repeat => block.text,
        };
      })
      .join('\n\n');
}
