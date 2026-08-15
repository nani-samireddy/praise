import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/text/telugu_transliterator.dart';

void main() {
  test('transliterates a Telugu song title into readable Latin text', () {
    expect(
      transliterateTeluguTitle('పదే పదే నేను పాడుకోనా'),
      'Pade Pade Nenu Paadukonaa',
    );
  });

  test('handles conjuncts, anusvara, punctuation, and Telugu digits', () {
    expect(transliterateTeluguTitle('క్రీస్తు'), 'Kreestu');
    expect(transliterateTeluguTitle('వందనం'), 'Vandanam');
    expect(transliterateTeluguTitle('యేసు - ౨'), 'Yesu - 2');
  });

  test('keeps an already Latin title useful as its English title', () {
    expect(transliterateTeluguTitle('my worship song'), 'My Worship Song');
  });
}
