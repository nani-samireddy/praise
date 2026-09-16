import 'dart:convert';

import 'package:flutter/material.dart';

import 'chord_transposer.dart';

class StructuredLyrics extends StatelessWidget {
  const StructuredLyrics({
    super.key,
    required this.json,
    required this.fontSize,
    this.fontFamily,
    this.expandCounts = false,
    this.showTransliteration = false,
    this.transposeSemitones = 0,
    this.showChords = true,
    this.showGuitarShapes = false,
    this.showHarmonyParts = false,
  });

  final String json;
  final double fontSize;
  final String? fontFamily;
  final bool expandCounts;
  final bool showTransliteration;
  final int transposeSemitones;
  final bool showChords;
  final bool showGuitarShapes;
  final bool showHarmonyParts;

  @override
  Widget build(BuildContext context) {
    final decoded = jsonDecode(json);
    final sections = decoded is Map ? decoded['sections'] : null;
    if (sections is! List) return const SizedBox.shrink();
    final originalKey = decoded is Map && decoded['originalKey'] is String
        ? decoded['originalKey'] as String
        : null;
    final targetKey = transposeKey(originalKey ?? '', transposeSemitones);
    final rawCapo = decoded is Map ? decoded['capo'] : null;
    final capo = rawCapo is num ? rawCapo.toInt().clamp(0, 12).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections.whereType<Map>()) ...[
          if (section['label'] is String)
            Padding(
              padding: const EdgeInsets.only(top: 26, bottom: 14),
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
              showTransliteration: showTransliteration,
              transposeSemitones: transposeSemitones,
              targetKey: targetKey,
              showChords: showChords,
              capo: capo,
              showGuitarShapes: showGuitarShapes,
            ),
        ],
        if (showHarmonyParts && decoded is Map)
          for (final part
              in (decoded['harmonyParts'] is List
                      ? decoded['harmonyParts'] as List
                      : const [])
                  .whereType<Map>()) ...[
            if (part['label'] is String)
              Padding(
                padding: const EdgeInsets.only(top: 28, bottom: 14),
                child: Text(
                  (part['label'] as String).toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            for (final line
                in (part['lines'] is List ? part['lines'] as List : const [])
                    .whereType<Map>())
              _Line(
                line: line,
                fontSize: fontSize,
                fontFamily: fontFamily,
                expand: expandCounts,
                showTransliteration: showTransliteration,
                transposeSemitones: transposeSemitones,
                targetKey: targetKey,
                showChords: showChords,
                capo: capo,
                showGuitarShapes: showGuitarShapes,
              ),
          ],
      ],
    );
  }
}

class _LyricSegment {
  const _LyricSegment({required this.text, this.chord});

  final String text;
  final String? chord;
}

List<_LyricSegment> _readSegments(Map line) {
  final rawSegments = line['segments'];
  if (rawSegments is! List) return const [];

  return [
    for (final rawSegment in rawSegments.whereType<Map>())
      if (rawSegment['text'] is String &&
          (rawSegment['text'] as String).isNotEmpty)
        _LyricSegment(
          text: rawSegment['text'] as String,
          chord: rawSegment['chord']?.toString().trim().isEmpty == true
              ? null
              : rawSegment['chord']?.toString().trim(),
        ),
  ];
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.fontSize,
    this.fontFamily,
    required this.expand,
    required this.showTransliteration,
    required this.transposeSemitones,
    required this.targetKey,
    required this.showChords,
    required this.capo,
    required this.showGuitarShapes,
  });

  final Map line;
  final double fontSize;
  final String? fontFamily;
  final bool expand;
  final bool showTransliteration;
  final int transposeSemitones;
  final String targetKey;
  final bool showChords;
  final int capo;
  final bool showGuitarShapes;

  @override
  Widget build(BuildContext context) {
    final text = line['text'] as String? ?? '';
    final latin = showTransliteration
        ? line['transliteration'] as String?
        : null;
    final segments = _readSegments(line);
    final segmentText = segments.map((segment) => segment.text).join(' ');
    final lyricText = text.isNotEmpty ? text : segmentText;
    final hasChords = segments.any((segment) => segment.chord != null);
    final count = (line['repeatCount'] as num?)?.toInt() ?? 1;
    final copies = expand ? count : 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < copies; i++) ...[
            if (i > 0) SizedBox(height: fontSize * .45),
            if (showChords && hasChords)
              _SegmentedChordLine(
                segments: segments,
                fontSize: fontSize,
                fontFamily: fontFamily,
                transposeSemitones: transposeSemitones,
                targetKey: targetKey,
                capo: capo,
                showGuitarShapes: showGuitarShapes,
              )
            else
              Text(
                lyricText,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  height: 1.6,
                ),
              ),
            if (latin != null)
              Text(
                latin,
                style: TextStyle(
                  fontSize: fontSize * .68,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
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

class _SegmentedChordLine extends StatelessWidget {
  const _SegmentedChordLine({
    required this.segments,
    required this.fontSize,
    required this.transposeSemitones,
    required this.targetKey,
    required this.capo,
    required this.showGuitarShapes,
    this.fontFamily,
  });

  final List<_LyricSegment> segments;
  final double fontSize;
  final int transposeSemitones;
  final String targetKey;
  final String? fontFamily;
  final int capo;
  final bool showGuitarShapes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final chordHeight = fontSize * .72 * 1.2 + 4;
    final shapeHeight = fontSize * .5 * 1.2 + 6;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          runSpacing: 8,
          children: [
            for (var index = 0; index < segments.length; index++)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Padding(
                  padding: EdgeInsets.only(right: _segmentGap(index)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height:
                            chordHeight +
                            (showGuitarShapes && capo > 0 ? shapeHeight : 0),
                        child: segments[index].chord == null
                            ? null
                            : showGuitarShapes && capo > 0
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _chordText(segments[index].chord!, color),
                                  Text(
                                    'shape ${_guitarShape(segments[index].chord!)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: color.withValues(alpha: .75),
                                      fontSize: fontSize * .5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : _chordText(segments[index].chord!, color),
                      ),
                      Text(
                        segments[index].text,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _displayChord(String chord) =>
      transposeChord(chord, transposeSemitones, targetKey: targetKey);

  String _guitarShape(String chord) =>
      transposeChord(_displayChord(chord), -capo);

  Widget _chordText(String chord, Color color) => Text(
    _displayChord(chord),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: fontSize * .72,
    ),
  );

  double _segmentGap(int index) {
    if (index == segments.length - 1) return 0;
    final currentText = segments[index].text;
    final nextText = segments[index + 1].text;
    if (RegExp(r'\s$').hasMatch(currentText) ||
        RegExp(r'^\s').hasMatch(nextText)) {
      return 0;
    }
    return 4;
  }
}
