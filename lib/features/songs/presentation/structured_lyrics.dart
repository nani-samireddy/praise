import 'dart:convert';

import 'package:flutter/material.dart';

class StructuredLyrics extends StatelessWidget {
  const StructuredLyrics({
    super.key,
    required this.json,
    required this.fontSize,
    this.fontFamily,
    this.expandCounts = false,
  });
  final String json;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;
  @override
  Widget build(BuildContext context) {
    final decoded = jsonDecode(json);
    final sections = decoded is Map ? decoded['sections'] : null;
    if (sections is! List) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections.whereType<Map>()) ...[
          if (section['label'] is String)
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 10),
              child: Text(
                (section['label'] as String).toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          for (final line
              in (section['lines'] is List
                      ? section['lines'] as List
                      : const [])
                  .whereType<Map>())
            _Line(
              line: line,
              fontSize: fontSize,
              fontFamily: fontFamily,
              expand: expandCounts,
            ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.fontSize,
    this.fontFamily,
    required this.expand,
  });
  final Map line;
  final double fontSize;
  final String? fontFamily;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final text = line['text'] as String? ?? '';
    final latin = line['transliteration'] as String?;
    final chords =
        (line['chords'] as List?)?.whereType<Map>().toList() ?? const [];
    final count = (line['repeatCount'] as num?)?.toInt() ?? 1;
    final copies = expand ? count : 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chords.isNotEmpty)
            _ChordLine(
              text: text,
              chords: chords,
              fontSize: fontSize,
              fontFamily: fontFamily,
            ),
          for (var i = 0; i < copies; i++) ...[
            Text(
              text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize,
                height: 1.45,
              ),
            ),
            if (latin != null)
              Text(
                latin,
                style: TextStyle(
                  fontSize: fontSize * .68,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (!expand && count > 1)
            Text(
              '×$count',
              style: TextStyle(
                fontSize: fontSize * .68,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChordLine extends StatelessWidget {
  const _ChordLine({
    required this.text,
    required this.chords,
    required this.fontSize,
    this.fontFamily,
  });
  final String text;
  final List<Map> chords;
  final double fontSize;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    final points =
        chords
            .map(
              (entry) => (
                at: ((entry['at'] as num?)?.toInt() ?? 0).clamp(
                  0,
                  chars.length,
                ),
                chord: entry['chord']?.toString() ?? '',
              ),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return Wrap(
      spacing: 2,
      runSpacing: 4,
      children: [
        for (var i = 0; i < points.length; i++)
          _ChordSegment(
            chord: points[i].chord,
            text: chars
                .sublist(
                  points[i].at,
                  i + 1 < points.length ? points[i + 1].at : chars.length,
                )
                .join(),
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
      ],
    );
  }
}

class _ChordSegment extends StatelessWidget {
  const _ChordSegment({
    required this.chord,
    required this.text,
    required this.fontSize,
    this.fontFamily,
  });
  final String chord, text;
  final double fontSize;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        chord,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w800,
          fontSize: fontSize * .72,
        ),
      ),
      Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.45,
        ),
      ),
    ],
  );
}
