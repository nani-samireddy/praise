import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/structured_lyrics.dart';

void main() {
  testWidgets('renders chord-attached lyric segments responsively', (
    tester,
  ) async {
    const json = '''
      {
        "originalKey": "Em",
        "capo": 2,
        "sections": [
          {
            "label": "Verse 1",
            "lines": [
              {
                "text": "జుంటె తేనె కన్నా తీయనిది",
                "transliteration": "Junte Thene Kannaa Theeyanidi",
                "segments": [
                  {"text": "జుంటె", "chord": "Em"},
                  {"text": "తేనె కన్నా", "chord": "G"},
                  {"text": "తీయనిది", "chord": "D"}
                ]
              }
            ]
          }
        ],
        "harmonyParts": [
          {
            "label": "Alto",
            "lines": [
              {"text": "ఆల్టో గీతము"}
            ]
          }
        ]
      }
    ''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SingleChildScrollView(
              child: StructuredLyrics(json: json, fontSize: 24),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Em'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Junte Thene Kannaa Theeyanidi'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SingleChildScrollView(
              child: StructuredLyrics(
                json: json,
                fontSize: 24,
                transposeSemitones: 2,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('F#m'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SingleChildScrollView(
              child: StructuredLyrics(
                json: json,
                fontSize: 24,
                showChords: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('జుంటె తేనె కన్నా తీయనిది'), findsOneWidget);
    expect(find.text('Em'), findsNothing);
    expect(find.text('G'), findsNothing);
    expect(find.text('D'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SingleChildScrollView(
              child: StructuredLyrics(
                json: json,
                fontSize: 24,
                showGuitarShapes: true,
                showHarmonyParts: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('shape Dm'), findsOneWidget);
    expect(find.text('ALTO'), findsOneWidget);
    expect(find.text('ఆల్టో గీతము'), findsOneWidget);
  });
}
