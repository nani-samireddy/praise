import 'dart:convert';

import 'chord_transposer.dart';

/// Usable local content, independent of role and feature preferences.
class SongArrangement {
  SongArrangement._(this.data);

  final Map<String, dynamic> data;

  factory SongArrangement.parse(String? source) {
    try {
      final decoded = source == null ? null : jsonDecode(source);
      if (decoded is! Map) return SongArrangement._({});
      List<Map<String, dynamic>> groups(Object? raw) => [
        if (raw is List)
          for (final group in raw.whereType<Map>())
            {
              if (group['label'] is String) 'label': group['label'],
              if (group['type'] is String) 'type': group['type'],
              if (group['transliterationLabel'] is String)
                'transliterationLabel': group['transliterationLabel'],
              'lines': [
                if (group['lines'] is List)
                  for (final line in (group['lines'] as List).whereType<Map>())
                    {
                      if (line['text'] is String) 'text': line['text'],
                      if (line['transliteration'] is String)
                        'transliteration': line['transliteration'],
                      if (line['repeatCount'] is num &&
                          (line['repeatCount'] as num).isFinite)
                        'repeatCount': (line['repeatCount'] as num)
                            .toInt()
                            .clamp(1, 100),
                      'segments': [
                        if (line['segments'] is List)
                          for (final segment
                              in (line['segments'] as List).whereType<Map>())
                            if (segment['text'] is String &&
                                (segment['text'] as String).trim().isNotEmpty)
                              {
                                'text': segment['text'],
                                if (segment['transliteration'] is String)
                                  'transliteration': segment['transliteration'],
                                if (segment['chord'] is String &&
                                    isSupportedChord(
                                      segment['chord'] as String,
                                    ))
                                  'chord': (segment['chord'] as String).trim(),
                              },
                      ],
                    },
              ],
            },
      ];
      final rawCapo = decoded['capo'];
      return SongArrangement._({
        'sections': groups(decoded['sections']),
        'harmonyParts': groups(decoded['harmonyParts']),
        if (decoded['originalKey'] is String &&
            isSupportedKey(decoded['originalKey'] as String))
          'originalKey': (decoded['originalKey'] as String).trim(),
        'capo':
            rawCapo is num &&
                rawCapo.isFinite &&
                rawCapo == rawCapo.toInt() &&
                rawCapo >= 0 &&
                rawCapo <= 12
            ? rawCapo.toInt()
            : 0,
      });
    } on FormatException {
      return SongArrangement._({});
    }
  }

  Iterable<Map> _lines(String group) sync* {
    for (final section in (data[group] as List? ?? const []).whereType<Map>()) {
      yield* (section['lines'] as List).whereType<Map>();
    }
  }

  bool _readable(Map line) =>
      (line['text'] is String && (line['text'] as String).trim().isNotEmpty) ||
      (line['segments'] as List).isNotEmpty;

  bool get hasLyrics => _lines('sections').any(_readable);
  bool get hasChords =>
      hasLyrics &&
      _lines('sections').any(
        (line) => (line['segments'] as List).whereType<Map>().any(
          (s) => s['chord'] != null,
        ),
      );
  bool get hasHarmony => hasLyrics && _lines('harmonyParts').any(_readable);
  String? get originalKey => data['originalKey'] as String?;
  int get capo => data['capo'] as int? ?? 0;
  String? get usableJson => hasLyrics ? jsonEncode(data) : null;

  bool chordsAvailable(bool enabled) => enabled && hasChords;
  bool transposeAvailable(bool chordsEnabled, bool transposeEnabled) =>
      chordsAvailable(chordsEnabled) && transposeEnabled;
  bool shapesAvailable(bool chordsEnabled, bool shapesEnabled) =>
      chordsAvailable(chordsEnabled) && shapesEnabled && capo > 0;
  bool harmonyAvailable(bool enabled) => enabled && hasHarmony;
}
