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
}
