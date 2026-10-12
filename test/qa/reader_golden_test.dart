import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/formatted_lyrics.dart';

import 'ui_qa_fixture.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoSansTelugu')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTelugu-Variable.ttf'));
    await loader.load();
  });
  for (final brightness in Brightness.values) {
    testWidgets('Telugu reader golden $brightness 200%', (tester) async {
      await pumpQaSurface(
        tester,
        size: qaViewports['small phone']!,
        brightness: brightness,
        child: RepaintBoundary(
          key: const ValueKey('reader-golden'),
          child: ColoredBox(
            color: brightness == Brightness.light
                ? Colors.white
                : const Color(0xff121212),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BilingualFormattedLyrics(
                  primaryBody: qaTeluguTitle,
                  englishBody: 'Praise and worship',
                  primaryFontFamily: 'NotoSansTelugu',
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('reader-golden')),
        matchesGoldenFile('goldens/reader_${brightness.name}_200.png'),
      );
    });
  }
}
