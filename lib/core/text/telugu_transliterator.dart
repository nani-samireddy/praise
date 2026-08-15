const _independentVowels = <String, String>{
  'అ': 'a',
  'ఆ': 'aa',
  'ఇ': 'i',
  'ఈ': 'ee',
  'ఉ': 'u',
  'ఊ': 'oo',
  'ఋ': 'ru',
  'ౠ': 'roo',
  'ఌ': 'lu',
  'ౡ': 'loo',
  'ఎ': 'e',
  'ఏ': 'e',
  'ఐ': 'ai',
  'ఒ': 'o',
  'ఓ': 'o',
  'ఔ': 'au',
};

const _consonants = <String, String>{
  'క': 'k',
  'ఖ': 'kh',
  'గ': 'g',
  'ఘ': 'gh',
  'ఙ': 'ng',
  'చ': 'ch',
  'ఛ': 'chh',
  'జ': 'j',
  'ఝ': 'jh',
  'ఞ': 'ny',
  'ట': 't',
  'ఠ': 'th',
  'డ': 'd',
  'ఢ': 'dh',
  'ణ': 'n',
  'త': 't',
  'థ': 'th',
  'ద': 'd',
  'ధ': 'dh',
  'న': 'n',
  'ప': 'p',
  'ఫ': 'ph',
  'బ': 'b',
  'భ': 'bh',
  'మ': 'm',
  'య': 'y',
  'ర': 'r',
  'ఱ': 'r',
  'ల': 'l',
  'ళ': 'l',
  'వ': 'v',
  'శ': 'sh',
  'ష': 'sh',
  'స': 's',
  'హ': 'h',
};

const _vowelSigns = <String, String>{
  'ా': 'aa',
  'ి': 'i',
  'ీ': 'ee',
  'ు': 'u',
  'ూ': 'oo',
  'ృ': 'ru',
  'ౄ': 'roo',
  'ౢ': 'lu',
  'ౣ': 'loo',
  'ె': 'e',
  'ే': 'e',
  'ై': 'ai',
  'ొ': 'o',
  'ో': 'o',
  'ౌ': 'au',
};

const _teluguDigits = <String, String>{
  '౦': '0',
  '౧': '1',
  '౨': '2',
  '౩': '3',
  '౪': '4',
  '౫': '5',
  '౬': '6',
  '౭': '7',
  '౮': '8',
  '౯': '9',
};

/// Produces a readable Latin-script title without using a network service.
String transliterateTeluguTitle(String value) {
  final characters = value.runes
      .map(String.fromCharCode)
      .toList(growable: false);
  final output = StringBuffer();
  for (var index = 0; index < characters.length; index++) {
    final character = characters[index];
    final consonant = _consonants[character];
    if (consonant != null) {
      output.write(consonant);
      final next = index + 1 < characters.length ? characters[index + 1] : null;
      if (next == '్') {
        index++;
      } else if (next != null && _vowelSigns.containsKey(next)) {
        output.write(_vowelSigns[next]);
        index++;
      } else {
        output.write('a');
      }
      continue;
    }
    if (_independentVowels[character] case final vowel?) {
      output.write(vowel);
    } else if (_vowelSigns[character] case final vowelSign?) {
      output.write(vowelSign);
    } else if (character == 'ం') {
      final next = index + 1 < characters.length ? characters[index + 1] : null;
      output.write(_anusvara(next));
    } else if (character == 'ఁ') {
      output.write('n');
    } else if (character == 'ః') {
      output.write('h');
    } else if (character == 'ఽ') {
      output.write("'");
    } else if (character == '్' ||
        character == '\u200C' ||
        character == '\u200D') {
      continue;
    } else {
      output.write(_teluguDigits[character] ?? character);
    }
  }
  return _titleCase(output.toString().trim());
}

String _anusvara(String? next) {
  if (next == null || next.trim().isEmpty) return 'm';
  return const {'ప', 'ఫ', 'బ', 'భ', 'మ'}.contains(next) ? 'm' : 'n';
}

String _titleCase(String value) {
  return value.splitMapJoin(
    RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?"),
    onMatch: (match) {
      final word = match[0]!;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    },
    onNonMatch: (text) => text,
  );
}
