import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/settings/data/feature_flags.dart';
import 'package:praise/features/settings/data/settings_repository.dart';
import 'package:praise/features/settings/data/telugu_font.dart';
import 'package:praise/features/settings/presentation/settings_providers.dart';
import 'package:praise/features/settings/presentation/feature_providers.dart';
import 'package:praise/features/favorites/presentation/favorite_providers.dart';
import 'package:praise/features/songs/presentation/song_providers.dart';
import 'package:praise/features/songs/presentation/song_arrangement.dart';
import 'package:praise/features/songs/presentation/song_detail_screen.dart';

String arrangement({
  Object? chord = 'C',
  Object? key,
  Object? capo = 0,
  bool harmony = false,
}) => jsonEncode({
  'originalKey': key,
  'capo': capo,
  'sections': [
    {
      'lines': [
        {
          'text': 'గీతము',
          'segments': [
            {'text': 'గీతము', 'chord': chord},
          ],
        },
      ],
    },
  ],
  'harmonyParts': harmony
      ? [
          {
            'label': 'Alto',
            'lines': [
              {'text': 'Harmony lyric'},
            ],
          },
        ]
      : [],
});

void main() {
  test('availability requires usable content', () {
    for (final source in [
      null,
      '',
      '{',
      '[]',
      '{}',
      '{"sections":42}',
      arrangement(chord: 42),
    ]) {
      expect(SongArrangement.parse(source).hasChords, isFalse);
    }
    final content = SongArrangement.parse(arrangement(capo: 2, harmony: true));
    expect(content.originalKey, isNull);
    expect(content.transposeAvailable(true, true), isTrue);
    expect(content.transposeAvailable(false, true), isFalse);
    expect(content.shapesAvailable(true, true), isTrue);
    expect(content.shapesAvailable(true, false), isFalse);
    expect(content.harmonyAvailable(true), isTrue);
    expect(content.harmonyAvailable(false), isFalse);
    for (final capo in [-1, 13, 1.5, '2']) {
      expect(SongArrangement.parse(arrangement(capo: capo)).capo, 0);
    }
    expect(
      SongArrangement.parse(arrangement(key: 'unknown')).originalKey,
      isNull,
    );
    expect(SongArrangement.parse(arrangement(key: 'Em')).originalKey, 'Em');
    expect(
      SongArrangement.parse('{"harmonyParts":[{"lines":[{}]}]}').hasHarmony,
      isFalse,
    );
  });

  for (final scenario in <String, String?>{
    'no arrangement': null,
    'malformed data': '{',
    'lyrics only': arrangement(chord: null),
    'malformed fields': '{"sections":[{"lines":[{"text":42,"repeatCount":"bad","segments":[{"text":null,"chord":"C"}]}]}]}',
    'chords without key': arrangement(),
    'capo and harmony': arrangement(key: 'Em', capo: 2, harmony: true),
  }.entries) {
    testWidgets('reader controls: ${scenario.key}', (tester) async {
      final semantics = tester.ensureSemantics();
      final now = DateTime.utc(2026);
      final song = Song(
        id: 'song',
        title: 'Song',
        body: 'గీతము',
        structureJson: scenario.value,
        source: 'server',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songProvider('song').overrideWith((ref) => Stream.value(song)),
            songNoteProvider('song').overrideWith((ref) => Stream.value(null)),
            isFavoriteProvider('song')
                .overrideWith((ref) => Stream.value(false)),
            lyricsFontSizeProvider.overrideWith((ref) => Stream.value(19)),
            lyricsDisplayModeProvider.overrideWith(
              (ref) => Stream.value(LyricsDisplayMode.primary),
            ),
            teluguFontProvider.overrideWith(
              (ref) => Stream.value(TeluguFont.system),
            ),
            for (final feature in FeatureKey.values)
              featureEnabledProvider(feature).overrideWith((ref) async* {
                yield true;
              }),
          ],
          child: const MaterialApp(home: SongDetailScreen(songId: 'song')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show chords'), findsNothing);
      expect(find.text('గీతము'), findsOneWidget);
      final toggle = find.widgetWithText(TextButton, 'Song controls');
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.widgetWithText(TextButton, 'Hide controls'))
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
      final hasChords = SongArrangement.parse(scenario.value).hasChords;
      expect(
        find.text('Show chords'),
        hasChords ? findsOneWidget : findsNothing,
      );
      expect(find.text('Metronome'), findsOneWidget);
      expect(find.text('Transpose'), findsNothing);
      if (hasChords) {
        await tester.ensureVisible(find.text('Show chords'));
        await tester.tap(find.text('Show chords'));
        await tester.pumpAndSettle();
        expect(find.text('Transpose'), findsOneWidget);
        if (scenario.key == 'chords without key') {
          expect(
            find.text('Key not provided · Shift by semitones'),
            findsOneWidget,
          );
        }
      }
      expect(
        find.text('Show harmony parts'),
        scenario.key == 'capo and harmony' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Guitar chord shapes'),
        scenario.key == 'capo and harmony' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
