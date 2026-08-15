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
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CustomSongEditorScreen(scannedDraft: draft)),
      ),
    );

    expect(find.text('Review scanned song'), findsOneWidget);
    expect(find.textContaining('OCR can make mistakes'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, draft.title), findsOneWidget);
    expect(find.widgetWithText(TextFormField, draft.body), findsOneWidget);
  });
}
