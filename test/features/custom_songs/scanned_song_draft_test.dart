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

  test('creates a complete draft from structured on-device AI fields', () {
    final draft = createAiScannedSongDraft({
      'title': '  పదే పదే  ',
      'englishTitle': '  Pade Pade  ',
      'body': 'పదే పదే  \n\n\nప్రతి చోట',
      'englishBody': '',
      'author': '  Test Author ',
    }, recognizedText: 'పదే పదే\nPade Pade\nTest Author');

    expect(draft.title, 'పదే పదే');
    expect(draft.englishTitle, 'Pade Pade');
    expect(draft.body, 'పదే పదే\n\nప్రతి చోట');
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
}
