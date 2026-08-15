import '../../../core/text/telugu_transliterator.dart';

class ScannedSongDraft {
  const ScannedSongDraft({
    required this.title,
    required this.body,
    this.englishTitle,
    this.englishBody,
    this.author,
    this.aiEnhanced = false,
    this.aiFallback = false,
  });

  final String title;
  final String? englishTitle;
  final String body;
  final String? englishBody;
  final String? author;
  final bool aiEnhanced;
  final bool aiFallback;
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
  final englishTitle =
      extractedEnglishTitle != null &&
          _appearsInOcr(extractedEnglishTitle, recognizedText)
      ? extractedEnglishTitle
      : transliterateTeluguTitle(title);
  return ScannedSongDraft(
    title: title,
    englishTitle: englishTitle,
    body: body,
    englishBody: _normalizedField(value['englishBody']),
    author: _normalizedField(value['author']),
    aiEnhanced: true,
  );
}

String normalizeScannedLyrics(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

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
