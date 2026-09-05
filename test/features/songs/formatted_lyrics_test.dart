import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/formatted_lyrics.dart';

void main() {
  testWidgets('song-level option controls all annotated lyric lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedLyrics(
              body: 'Sing this line ×2\nThen this line ×3',
              fontSize: 19,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sing this line'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);

    expect(find.text('Sing this line'), findsOneWidget);
    expect(find.text('1/2'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedLyrics(
              body: 'Sing this line ×2\nThen this line ×3',
              fontSize: 19,
              expandCounts: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sing this line'), findsNWidgets(2));
    expect(find.text('Then this line'), findsNWidgets(3));
    expect(find.text('1/2'), findsNothing);
    expect(find.text('3/3'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('adds a full gap after labels and applies the Telugu font', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedLyrics(
            body: '''[Chorus]
మొదటి పంక్తి

[Repeat: ఆరాధన]
రెండవ పంక్తి''',
            fontSize: 20,
            fontFamily: 'Mandali',
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('మొదటి పంక్తి')).style?.fontFamily,
      'Mandali',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 30,
      ),
      findsNWidgets(2),
    );
    expect(
      tester.widget<Text>(find.text('ఆరాధన')).style?.fontSize,
      closeTo(14.4, 0.001),
    );
  });

  testWidgets('song-level option controls annotated lyric blocks', (
    tester,
  ) async {
    const body = '''
[Repeat ×2]
Line one
Line two
[/Repeat]''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedLyrics(body: body, fontSize: 19),
          ),
        ),
      ),
    );

    expect(find.text('Line one'), findsOneWidget);
    expect(find.text('Line two'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('[Repeat ×2]'), findsNothing);
    expect(find.text('[/Repeat]'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedLyrics(
              body: body,
              fontSize: 19,
              expandCounts: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Line one'), findsNWidgets(2));
    expect(find.text('Line two'), findsNWidgets(2));
    expect(find.text('×2'), findsNothing);
    expect(find.text('[Repeat ×2]'), findsNothing);
    expect(find.text('[/Repeat]'), findsNothing);
  });
}
