import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';

void main() {
  test('normalizes OCR spacing and suggests the first line as title', () {
    final draft = createScannedSongDraft(
      '  పదే పదే నేను పాడుకోనా  \r\nప్రతి చోట నీ మాట   \r\n\r\n\r\nAuthor',
    );

    expect(draft.title, 'పదే పదే నేను పాడుకోనా');
    expect(draft.englishTitle, 'Pade Pade Nenu Paadukonaa');
    expect(draft.body, 'పదే పదే నేను పాడుకోనా\nప్రతి చోట నీ మాట\n\nAuthor');
    expect(
      draft.englishBody,
      'Pade pade nenu paadukonaa\nPrati chota nee maata\n\nAuthor',
    );
  });

  test('uses a safe title when OCR returns whitespace', () {
    final draft = createScannedSongDraft(' \n ');

    expect(draft.title, 'Scanned song');
    expect(draft.body, isEmpty);
  });

  test('keeps the title blank when AI organization failed', () {
    const ocrText = '11:44 & @ © ue - ll > Os\nఇ నీ ప్రేమ ధార';
    final draft = createScannedSongDraft(ocrText, aiFallback: true);

    expect(draft.title, isEmpty);
    expect(draft.englishTitle, isEmpty);
    expect(draft.body, ocrText);
    expect(draft.englishBody, isEmpty);
    expect(draft.aiFallback, isTrue);
  });

  test('creates an image-only draft without running OCR', () {
    final draft = createPhotoSongDraft('/temporary/song-photo.jpg');

    expect(draft.title, isEmpty);
    expect(draft.body, isEmpty);
    expect(draft.imagePath, '/temporary/song-photo.jpg');
    expect(draft.aiEnhanced, isFalse);
  });

  test('normalizes inline and standalone OCR repetition counts', () {
    expect(
      normalizeScannedLyrics('First line x2\nSecond line\n*3\nThird line ✕4'),
      'First line ×2\nSecond line ×3\nThird line ×4',
    );
  });

  test('removes obvious scan controls and status-bar noise before AI', () {
    const scanText = '''
10:47 A @ © we « oll > Cs
€ 9 = 8
అంతే లేని నీ ప్రేమ ధార
Anthe Leni Nee Prema Dhaara.
3= Song controls
Lyrics
ఎంతో నాపై కురిపించినావు
''';

    expect(
      prepareOcrTextForSongAi(scanText),
      'అంతే లేని నీ ప్రేమ ధార\nAnthe Leni Nee Prema Dhaara.\nఎంతో నాపై కురిపించినావు',
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
    expect(draft.englishBody, 'Pade pade ×2\n\nPrati chota');
    expect(draft.author, 'Test Author');
    expect(draft.aiEnhanced, isTrue);
  });

  test(
    'uses AI transliteration and cleans spacing in its structured output',
    () {
      final draft = createAiScannedSongDraft(
        {
          'title': 'అంతే లేని నీ ప్రేమ ధార',
          'englishTitle': 'Anthe Leni Nee Prema Dhaara',
          'body': 'అంతే   లేని నీ ప్రేమ ధార\n\nఎంతో   నాపై కురిపించినావు',
          'englishBody':
              'Anthe leni nee prema dhaara\n\nEntho naapai kuripinchinaavu',
          'author': '',
        },
        recognizedText:
            '10:47 controls\nఅంతే లేని నీ ప్రేమ ధార\nఎంతో నాపై కురిపించినావు',
      );

      expect(draft.title, 'అంతే లేని నీ ప్రేమ ధార');
      expect(draft.englishTitle, 'Anthe Leni Nee Prema Dhaara');
      expect(draft.body, 'అంతే లేని నీ ప్రేమ ధార\n\nఎంతో నాపై కురిపించినావు');
      expect(
        draft.englishBody,
        'Anthe leni nee prema dhaara\n\nEntho naapai kuripinchinaavu',
      );
    },
  );

  test('rejects incomplete structured AI output', () {
    expect(
      () => createAiScannedSongDraft({
        'title': 'Song',
        'body': '',
      }, recognizedText: 'Song'),
      throwsFormatException,
    );
  });

  test('rejects a screen-chrome line as the AI song title', () {
    const recognizedText = '11:44 & @ © ue - ll > Os\nఇ నీ ప్రేమ ధార';

    expect(
      () => createAiScannedSongDraft({
        'title': '11:44 & @ © ue - ll > Os',
        'body': recognizedText,
      }, recognizedText: recognizedText),
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

  test('replaces OCR chrome titles and transliterates Telugu lyrics', () {
    final recognizedText = '''
10:47 A @ © we « oll > Cs
అంతే లేని నీ ప్రేమ ధార
ఎంతో నాపై కురిపించినావు
Anthe Leni Nee Prema Dhaara.
Song controls
Lyrics
    ''';
    final draft = createAiScannedSongDraft({
      'title': 'అంతే లేని నీ ప్రేమ ధార',
      'englishTitle': 'Anthe Leni Nee Prema Dhaara',
      'body': 'అంతే లేని నీ ప్రేమ ధార\nఎంతో నాపై కురిపించినావు',
      'englishBody': '',
      'author': '',
    }, recognizedText: recognizedText);

    expect(draft.title, 'అంతే లేని నీ ప్రేమ ధార');
    expect(draft.englishTitle, 'Anthe Leni Nee Prema Dhaara');
    expect(
      draft.englishBody,
      'Anthe leni nee prema dhaara\nEntho naapai kuripinchinaavu',
    );
    expect(draft.aiEnhanced, isTrue);
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
