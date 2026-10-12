import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/favorites/presentation/favorite_button.dart';
import 'package:praise/features/songs/presentation/formatted_lyrics.dart';
import 'package:praise/features/songs/presentation/song_list_card.dart';

import 'ui_qa_fixture.dart';

void main() {
  for (final viewport in qaViewports.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('song card ${viewport.key} $brightness at 200%', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();

        await pumpQaSurface(
          tester,
          size: viewport.value,
          brightness: brightness,
          child: const SingleChildScrollView(
            child: SongListCard.index(
              id: 'qa-song',
              title: qaTeluguTitle,
              englishTitle: qaEnglishTitle,
              author: 'Praise QA',
              source: 'custom',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(qaTeluguTitle), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(IconButton)),
          matchesSemantics(
            tooltip: 'Add to favorites',
            hasFocusAction: true,
            hasSelectedState: true,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,

            hasTapAction: true,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
      testWidgets('Telugu reader ${viewport.key} $brightness at 200%', (
        tester,
      ) async {
        await pumpQaSurface(
          tester,
          size: viewport.value,
          brightness: brightness,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BilingualFormattedLyrics(
                primaryBody: List.filled(12, qaTeluguTitle).join('\n\n'),
                englishBody: List.filled(12, qaEnglishTitle).join('\n\n'),
                fontSize: 24,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('card keyboard focus reaches song before favorite', (
    tester,
  ) async {
    await pumpQaSurface(
      tester,
      size: qaViewports['small phone']!,
      brightness: Brightness.light,
      child: const SongListCard.index(
        id: 'qa-song',
        title: qaTeluguTitle,
        source: 'server',
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ListTile>(),
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<IconButton>()
          ?.tooltip,
      'Add to favorites',
    );
  });
  testWidgets('favorite announces enabled toggle state', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpQaSurface(
      tester,
      size: qaViewports['small phone']!,
      brightness: Brightness.light,
      favorite: true,
      child: const FavoriteButton(songId: 'qa-song'),
    );
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        tooltip: 'Remove from favorites',
        hasFocusAction: true,
        hasSelectedState: true,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,

        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
