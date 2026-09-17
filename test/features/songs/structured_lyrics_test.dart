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
            "type": "repeat",
            "label": "[Repeat: అంతా]",
            "transliterationLabel": "[Repeat: Anthaa]",
            "lines": []
          },
          {
            "label": "Verse 1",
            "lines": [
              {
                "text": "జుంటె తేనె కన్నా తీయనిది",
                "transliteration": "Junte Thene Kannaa Theeyanidi",
                "repeatCount": 2,
                "segments": [
                  {
                    "text": "జుంటె",
                    "transliteration": "Junte",
                    "chord": "Em"
                  },
                  {
                    "text": "తేనె కన్నా",
                    "transliteration": "Thene Kannaa",
                    "chord": "G"
                  },
                  {
                    "text": "తీయనిది",
                    "transliteration": "Theeyanidi",
                    "chord": "D"
                  }
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
    expect(find.text('|| 2 ||'), findsOneWidget);
    expect(find.text('|| అంతా ||'), findsOneWidget);
    expect(find.text('Repeat: అంతా'), findsNothing);
    expect(find.text('[REPEAT: అంతా]'), findsNothing);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SingleChildScrollView(
              child: StructuredLyrics(
                json: json,
                fontSize: 24,
                showTransliteration: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Junte'), findsOneWidget);
    expect(find.text('Em'), findsNWidgets(2));

    expect(find.text('|| Anthaa ||'), findsOneWidget);
    expect(find.text('Repeat: Anthaa'), findsNothing);
  });

  testWidgets('uses normal spacing before a section repeater after a count', (
    tester,
  ) async {
    const json = '''
      {
        "sections": [
          {
            "label": "Verse",
            "lines": [
              {"text": "Counted line", "repeatCount": 2}
            ]
          },
          {
            "type": "repeat",
            "label": "[Repeat: Chorus]",
            "lines": []
          }
        ]
      }
    ''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StructuredLyrics(json: json, fontSize: 20)),
      ),
    );

    expect(find.text('|| 2 ||'), findsOneWidget);
    expect(find.text('|| Chorus ||'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.only(bottom: 28),
      ),
      findsNothing,
    );
  });
}
