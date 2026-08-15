import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';

void main() {
  test('normalizes OCR spacing and suggests the first line as title', () {
    final draft = createScannedSongDraft(
      '  పదే పదే నేను పాడుకోనా  \r\nప్రతి చోట నీ మాట   \r\n\r\n\r\nAuthor',
    );

    expect(draft.title, 'పదే పదే నేను పాడుకోనా');
    expect(draft.body, 'పదే పదే నేను పాడుకోనా\nప్రతి చోట నీ మాట\n\nAuthor');
  });

  test('uses a safe title when OCR returns whitespace', () {
    final draft = createScannedSongDraft(' \n ');

    expect(draft.title, 'Scanned song');
    expect(draft.body, isEmpty);
  });

  test('normalizes inline and standalone OCR repetition counts', () {
    expect(
      normalizeScannedLyrics('First line x2\nSecond line\n*3\nThird line ✕4'),
      'First line ×2\nSecond line ×3\nThird line ×4',
    );
  });

  test('creates a complete draft from structured on-device AI fields', () {
    final draft = createAiScannedSongDraft({
      'title': '  పదే పదే  ',
      'englishTitle': '  Pade Pade  ',
      'body': 'పదే పదే x2 \n\n\nప్రతి చోట',
      'englishBody': '',
      'author': '  Test Author ',
    }, recognizedText: 'పదే పదే x2\nప్రతి చోట\nPade Pade\nTest Author');

    expect(draft.title, 'పదే పదే');
    expect(draft.englishTitle, 'Pade Pade');
    expect(draft.body, 'పదే పదే ×2\n\nప్రతి చోట');
    expect(draft.englishBody, isNull);
    expect(draft.author, 'Test Author');
    expect(draft.aiEnhanced, isTrue);
  });

  test('rejects incomplete structured AI output', () {
    expect(
      () => createAiScannedSongDraft({
        'title': '',
        'body': 'Lyrics',
      }, recognizedText: 'Lyrics'),
      throwsFormatException,
    );
  });

  test('transliterates an AI title when no English heading was found', () {
    final draft = createAiScannedSongDraft({
      'title': 'పదే పదే నేను పాడుకోనా',
      'englishTitle': 'Sing Again and Again',
      'body': 'పదే పదే నేను పాడుకోనా x2',
    }, recognizedText: 'పదే పదే నేను పాడుకోనా x2');

    expect(draft.englishTitle, 'Pade Pade Nenu Paadukonaa');
  });

  test('falls back when AI drops a substantial part of the OCR lyrics', () {
    expect(
      () => createAiScannedSongDraft(
        {'title': 'పదే పదే', 'body': 'పదే పదే'},
        recognizedText: '''
పదే పదే నేను పాడుకోనా
ప్రతి చోట నీ మాట నా పాటగా
మరి మరి నే చాటుకోనా
మనసంతా పులకించని సాక్షిగా
''',
      ),
      throwsFormatException,
    );
  });
}
