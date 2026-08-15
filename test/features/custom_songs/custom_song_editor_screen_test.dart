import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';
import 'package:praise/features/custom_songs/presentation/custom_song_editor_screen.dart';

void main() {
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

    expect(find.text('Review scanned song'), findsOneWidget);
    expect(find.textContaining('On-device AI organized'), findsOneWidget);
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
    expect(find.text('Original song photo'), findsOneWidget);
    expect(find.text('Lyrics text'), findsOneWidget);
    expect(
      find.text('Optional when the original photo is kept'),
      findsOneWidget,
    );
  });
}
