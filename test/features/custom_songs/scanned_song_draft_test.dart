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
}
