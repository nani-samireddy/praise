import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/custom_songs/data/local_song_draft.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';
import 'package:praise/features/custom_songs/presentation/custom_song_editor_screen.dart';

void main() {
  testWidgets('starts manual entry with only the essential fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CustomSongEditorScreen())),
    );

    expect(find.text('Song title'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('More details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'English title'), findsNothing);

    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'English title'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Author or source'),
      findsOneWidget,
    );
  });

  testWidgets('recovers an unfinished manual entry', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await LocalSongDraftStore(database).save(
      const LocalSongDraft(
        title: 'Recovered song',
        englishTitle: '',
        body: 'Recovered lyrics',
        englishBody: '',
        author: '',
        maleVideoUrl: '',
        femaleVideoUrl: '',
        imagePath: null,
        detailsExpanded: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CustomSongEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unfinished song recovered'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Recovered song'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'Recovered lyrics'),
      findsOneWidget,
    );
  });

  testWidgets('opens recognized text for review before saving', (tester) async {
    const draft = ScannedSongDraft(
      title: 'పదే పదే నేను పాడుకోనా',
      body: 'పదే పదే నేను పాడుకోనా\nప్రతి చోట నీ మాట',
      englishTitle: 'Pade Pade Nenu Paadukonaa',
      author: 'Test Author',
      aiEnhanced: true,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CustomSongEditorScreen(scannedDraft: draft)),
      ),
    );

    expect(find.text('Review scanned lyrics'), findsOneWidget);
    expect(find.textContaining('organized on this device'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, draft.title), findsOneWidget);
    expect(find.widgetWithText(TextFormField, draft.body), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Pade Pade Nenu Paadukonaa'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Test Author'), findsOneWidget);
  });

  testWidgets('reviews a kept photo without requiring OCR lyrics', (
    tester,
  ) async {
    const draft = ScannedSongDraft(
      title: '',
      body: '',
      imagePath: '/missing/test-photo.jpg',
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CustomSongEditorScreen(scannedDraft: draft)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('original photo will be kept'), findsOneWidget);
    expect(find.text('Original photo'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(
      find.text('Optional when keeping the original photo'),
      findsOneWidget,
    );
  });
}
