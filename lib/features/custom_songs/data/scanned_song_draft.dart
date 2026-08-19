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
}

ScannedSongDraft createPhotoSongDraft(String imagePath) {
  return ScannedSongDraft(title: '', body: '', imagePath: imagePath);
}

ScannedSongDraft createScannedSongDraft(
  String recognizedText, {
  bool aiFallback = false,
}) {
  final normalized = normalizeScannedLyrics(recognizedText);
  final title = normalized
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => 'Scanned song');
  return ScannedSongDraft(
    title: title,
    body: normalized,
    aiFallback: aiFallback,
  );
}

ScannedSongDraft createAiScannedSongDraft(
  Map<Object?, Object?> value, {
  required String recognizedText,
}) {
  final title = _normalizedField(value['title']);
  final body = normalizeScannedLyrics(_normalizedField(value['body']) ?? '');
  if (title == null || body.isEmpty) {
    throw const FormatException('On-device AI returned an incomplete song.');
  }
  final extractedEnglishTitle = _normalizedField(value['englishTitle']);
  final sourceEnglishTitle =
      extractedEnglishTitle != null &&
          _appearsInOcr(extractedEnglishTitle, recognizedText)
      ? extractedEnglishTitle
      : null;
  final englishTitle = sourceEnglishTitle ?? transliterateTeluguTitle(title);
  final englishBody = _normalizedField(value['englishBody']);
  final author = _normalizedField(value['author']);
  final acceptedSourceText = [
    body,
    ?sourceEnglishTitle,
    ?englishBody,
    ?author,
  ].join('\n');
  if (!_hasAdequateCoverage(acceptedSourceText, recognizedText)) {
    throw const FormatException(
      'On-device AI omitted or invented too much song text.',
    );
  }
  return ScannedSongDraft(
    title: title,
    englishTitle: englishTitle,
    body: body,
    englishBody: englishBody,
    author: author,
    aiEnhanced: true,
  );
}

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

String _normalizeScannedLine(String line) {
  final trimmed = line.trimRight();
  final inlineCount = RegExp(
    r'^(.+?\S)\s*(?:[xX*×✕]|\((?=[2-9]|1[0-2]\))|\"(?=[2-9]|1[0-2]\"))\s*([2-9]|1[0-2])\s*[\)\"]?\s*$',
  ).firstMatch(trimmed);
  return inlineCount == null
      ? trimmed
      : '${inlineCount.group(1)} ×${inlineCount.group(2)}';
}

final _standaloneRepeatPattern =
    RegExp(r'^(?:[xX*×✕]|\((?=[2-9]|1[0-2]\))|\"(?=[2-9]|1[0-2]\"))\s*([2-9]|1[0-2])[\)\"]?$');

String? _normalizedField(Object? value) {
  if (value is! String) return null;
  final normalized = normalizeScannedLyrics(value);
  return normalized.isEmpty ? null : normalized;
}

bool _appearsInOcr(String candidate, String recognizedText) {
  final sourceWords = _latinWords(recognizedText).toSet();
  final candidateWords = _latinWords(candidate)
      .where((word) => word.length > 1)
      .toList(growable: false);
  return candidateWords.isNotEmpty &&
      candidateWords.every(sourceWords.contains);
}

Iterable<String> _latinWords(String value) sync* {
  for (final match in RegExp(r'[A-Za-z]+').allMatches(value.toLowerCase())) {
    yield match[0]!;
  }
}

bool _hasAdequateCoverage(String result, String source) {
  final sourceCharacters = _contentCharacters(source);
  final resultCharacters = _contentCharacters(result);
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
