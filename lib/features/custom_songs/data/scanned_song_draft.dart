import '../../../core/text/telugu_transliterator.dart';

class ScannedSongDraft {
  const ScannedSongDraft({
    required this.title,
    required this.body,
    this.englishTitle,
    this.englishBody,
    this.author,
    this.imagePath,
    this.aiEnhanced = false,
    this.aiFallback = false,
  });

  final String title;
  final String? englishTitle;
  final String body;
  final String? englishBody;
  final String? author;
  final String? imagePath;
  final bool aiEnhanced;
  final bool aiFallback;

  ScannedSongDraft withImagePath(String path) => ScannedSongDraft(
    title: title,
    body: body,
    englishTitle: englishTitle,
    englishBody: englishBody,
    author: author,
    imagePath: path,
    aiEnhanced: aiEnhanced,
    aiFallback: aiFallback,
  );
}

ScannedSongDraft createPhotoSongDraft(String imagePath) {
  return ScannedSongDraft(title: '', body: '', imagePath: imagePath);
}

ScannedSongDraft createScannedSongDraft(
  String recognizedText, {
  bool aiFallback = false,
}) {
  final normalized = normalizeScannedLyrics(recognizedText);
  final title = aiFallback
      ? ''
      : normalized
            .split('\n')
            .map((line) => line.trim())
            .firstWhere(_isMeaningfulTitleLine, orElse: () => 'Scanned song');
  return ScannedSongDraft(
    title: title,
    englishTitle: aiFallback ? '' : _englishTitleFor(title),
    body: normalized,
    englishBody: aiFallback ? '' : transliterateTeluguLyrics(normalized),
    aiFallback: aiFallback,
  );
}

ScannedSongDraft createAiScannedSongDraft(
  Map<Object?, Object?> value, {
  required String recognizedText,
}) {
  final body = normalizeScannedLyrics(_normalizedField(value['body']) ?? '');
  if (body.isEmpty) {
    throw const FormatException('On-device AI returned an incomplete song.');
  }
  final extractedTitle = _normalizedField(value['title']);
  if (extractedTitle == null ||
      !_isPlausibleSongTitle(extractedTitle, body, recognizedText)) {
    throw const FormatException(
      'Couldn’t identify a credible song title from this scan.',
    );
  }
  final title = extractedTitle;
  final extractedEnglishTitle = _normalizedField(value['englishTitle']);
  final sourceEnglishTitle =
      extractedEnglishTitle != null &&
          _isPlausibleEnglishTitle(extractedEnglishTitle, title, recognizedText)
      ? extractedEnglishTitle
      : null;
  final englishTitle = sourceEnglishTitle ?? _englishTitleFor(title);
  final extractedEnglishBody = _normalizedField(value['englishBody']);
  final englishBody =
      extractedEnglishBody != null &&
          _isPlausibleEnglishText(extractedEnglishBody)
      ? extractedEnglishBody
      : null;
  final extractedAuthor = _normalizedField(value['author']);
  final author =
      extractedAuthor != null &&
          _containsPhrase(recognizedText, extractedAuthor)
      ? extractedAuthor
      : null;
  if (!_hasAdequateCoverage(body, recognizedText)) {
    throw const FormatException(
      'On-device AI omitted or invented too much song text.',
    );
  }
  return ScannedSongDraft(
    title: title,
    englishTitle: englishTitle,
    body: body,
    englishBody: englishBody ?? transliterateTeluguLyrics(body),
    author: author,
    aiEnhanced: true,
  );
}

bool _isMeaningfulTitleLine(String line) =>
    line.runes.where(_isTeluguOrLatinLetter).length >= 3;

bool _isPlausibleSongTitle(
  String candidate,
  String body,
  String recognizedText,
) {
  final bodyHasTelugu = body.runes.any(_isTeluguRune);
  final candidateHasTelugu = candidate.runes.any(_isTeluguRune);
  if (bodyHasTelugu && !candidateHasTelugu) return false;
  if (!_isMeaningfulTitleLine(candidate)) return false;
  return _containsPhrase(recognizedText, candidate) ||
      _containsPhrase(body, candidate);
}

bool _isPlausibleEnglishText(String candidate) {
  final letters = candidate.runes.where(_isLatinLetter).length;
  final visibleCharacters = candidate.runes
      .where(
        (rune) =>
            rune != 0x20 &&
            rune != 0x09 &&
            rune != 0x0a &&
            rune != 0x0d &&
            rune != 0x00d7,
      )
      .length;
  return letters >= 2 &&
      visibleCharacters > 0 &&
      letters / visibleCharacters >= 0.7;
}

bool _isPlausibleEnglishTitle(
  String candidate,
  String title,
  String recognizedText,
) {
  if (!_isPlausibleEnglishText(candidate)) return false;
  return _containsPhrase(recognizedText, candidate) ||
      _normalizeForPhraseMatch(candidate) ==
          _normalizeForPhraseMatch(_englishTitleFor(title));
}

String _englishTitleFor(String title) =>
    title.runes.any(_isTeluguRune) ? transliterateTeluguTitle(title) : title;

bool _containsPhrase(String source, String candidate) {
  final normalizedSource = _normalizeForPhraseMatch(source);
  final normalizedCandidate = _normalizeForPhraseMatch(candidate);
  return normalizedCandidate.isNotEmpty &&
      normalizedSource.contains(normalizedCandidate);
}

String _normalizeForPhraseMatch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u0c00-\u0c7f]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

bool _isTeluguOrLatinLetter(int rune) =>
    _isTeluguRune(rune) || _isLatinLetter(rune);

bool _isTeluguRune(int rune) => rune >= 0x0c00 && rune <= 0x0c7f;

bool _isLatinLetter(int rune) =>
    (rune >= 0x41 && rune <= 0x5a) || (rune >= 0x61 && rune <= 0x7a);

String normalizeScannedLyrics(String value) {
  final lines = <String>[];
  for (final rawLine
      in value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = _normalizeScannedLine(rawLine);
    final standaloneCount = _standaloneRepeatPattern.firstMatch(line.trim());
    if (standaloneCount != null && lines.isNotEmpty && lines.last.isNotEmpty) {
      lines[lines.length - 1] = '${lines.last} ×${standaloneCount.group(1)}';
    } else {
      lines.add(line);
    }
  }
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String prepareOcrTextForSongAi(String value) {
  final lines = <String>[];
  for (final rawLine in value.replaceAll('\r', '').split('\n')) {
    final line = _normalizeScannedLine(rawLine);
    if (line.isEmpty || _isLikelyScanChrome(line)) continue;
    lines.add(line);
  }
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

bool _isLikelyScanChrome(String line) {
  final normalized = line
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]+'), ' ')
      .trim();
  const interfaceLabels = [
    'lyrics',
    'song controls',
    'review scanned lyrics',
    'search google photos',
    'photos',
    'collections',
    'scan a song',
    'take a photo',
    'choose from gallery',
    'keep the photo',
    'original photo',
    'more details',
    'save song',
  ];
  if (interfaceLabels.any(
    (label) => normalized == label || normalized.contains(label),
  )) {
    return true;
  }
  if (line.runes.any(_isTeluguRune) ||
      RegExp(r'^(?:[xX*×✕])\s*([2-9]|1[0-2])$').hasMatch(line.trim())) {
    return false;
  }
  final runes = line.runes
      .where((rune) => rune != 0x20 && rune != 0x09)
      .toList();
  if (runes.isEmpty) return true;
  final noisyCharacters = runes.where((rune) {
    final isLetter = _isLatinLetter(rune);
    final isDigit = rune >= 0x30 && rune <= 0x39;
    return !isLetter && !isDigit;
  }).length;
  final letters = runes.where(_isLatinLetter).length;
  final digits = runes.where((rune) => rune >= 0x30 && rune <= 0x39).length;
  return letters < 20 && (noisyCharacters + digits) / runes.length >= 0.4;
}

String _normalizeScannedLine(String line) {
  final trimmed = line.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
  final inlineCount = RegExp(r'^(.+?\S)\s*(?:[xX*]|✕)\s*([2-9]|1[0-2])\s*$')
      .firstMatch(trimmed);
  return inlineCount == null
      ? trimmed
      : '${inlineCount.group(1)} ×${inlineCount.group(2)}';
}

final _standaloneRepeatPattern = RegExp(r'^(?:[xX*×✕])\s*([2-9]|1[0-2])$');

String? _normalizedField(Object? value) {
  if (value is! String) return null;
  final normalized = normalizeScannedLyrics(value);
  return normalized.isEmpty ? null : normalized;
}

bool _hasAdequateCoverage(String result, String source) {
  final sourceAllCharacters = _contentCharacters(source);
  final sourceTeluguCharacters = sourceAllCharacters
      .where((character) => character.runes.single >= 0x0c00)
      .toList(growable: false);
  final useTeluguCoverage =
      sourceTeluguCharacters.length >= 10 &&
      sourceTeluguCharacters.length / sourceAllCharacters.length >= 0.25;
  final sourceCharacters = useTeluguCoverage
      ? sourceTeluguCharacters
      : sourceAllCharacters;
  final allResultCharacters = _contentCharacters(result);
  final resultCharacters = useTeluguCoverage
      ? allResultCharacters
            .where((character) => character.runes.single >= 0x0c00)
            .toList(growable: false)
      : allResultCharacters;
  if (sourceCharacters.length < 10) return true;
  if (resultCharacters.isEmpty) return false;
  final remaining = <String, int>{};
  for (final character in sourceCharacters) {
    remaining.update(character, (count) => count + 1, ifAbsent: () => 1);
  }
  var overlap = 0;
  for (final character in resultCharacters) {
    final count = remaining[character] ?? 0;
    if (count == 0) continue;
    overlap++;
    if (count == 1) {
      remaining.remove(character);
    } else {
      remaining[character] = count - 1;
    }
  }
  final lengthRatio = resultCharacters.length / sourceCharacters.length;
  final shorterLength = sourceCharacters.length < resultCharacters.length
      ? sourceCharacters.length
      : resultCharacters.length;
  return lengthRatio >= 0.6 &&
      lengthRatio <= 1.35 &&
      overlap / shorterLength >= 0.68;
}

List<String> _contentCharacters(String value) {
  return value
      .toLowerCase()
      .runes
      .where(
        (rune) =>
            (rune >= 0x0c00 && rune <= 0x0c7f) ||
            (rune >= 0x61 && rune <= 0x7a) ||
            (rune >= 0x30 && rune <= 0x39),
      )
      .map(String.fromCharCode)
      .toList(growable: false);
}
