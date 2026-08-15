class ScannedSongDraft {
  const ScannedSongDraft({required this.title, required this.body});

  final String title;
  final String body;
}

ScannedSongDraft createScannedSongDraft(String recognizedText) {
  final normalized = normalizeScannedLyrics(recognizedText);
  final title = normalized
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => 'Scanned song');
  return ScannedSongDraft(title: title, body: normalized);
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
