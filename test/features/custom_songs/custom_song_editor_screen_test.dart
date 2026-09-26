import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/custom_songs/data/local_song_draft.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';
import 'package:praise/features/custom_songs/data/song_scan_service.dart';
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

    expect(find.text('Original photo'), findsOneWidget);
    expect(find.text('Read from image'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(
      find.text('Optional when keeping the original photo'),
      findsOneWidget,
    );
  });

  testWidgets('reads a photo only after the user taps Read from image', (
    tester,
  ) async {
    final scanService = _FakeSongScanService();
    const draft = ScannedSongDraft(
      title: '',
      body: '',
      imagePath: '/missing/test-photo.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [songScanServiceProvider.overrideWithValue(scanService)],
        child: const MaterialApp(
          home: CustomSongEditorScreen(scannedDraft: draft),
        ),
      ),
    );
    await tester.pump();

    expect(scanService.recognizeCalls, 0);
    await tester.tap(find.text('Read from image'));
    await tester.pumpAndSettle();

    expect(scanService.recognizeCalls, 1);
    expect(
      find.widgetWithText(TextFormField, 'తెలుగు పాట శీర్షిక'),
      findsOneWidget,
    );
    expect(find.textContaining('organized on this device'), findsOneWidget);
  });

  testWidgets('gets the Gemma Play Asset only after terms are accepted', (
    tester,
  ) async {
    final scanService = _FakeSongScanService(
      status: OnDeviceAiStatus.downloadable,
    );
    const draft = ScannedSongDraft(
      title: '',
      body: '',
      imagePath: '/missing/test-photo.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [songScanServiceProvider.overrideWithValue(scanService)],
        child: const MaterialApp(
          home: CustomSongEditorScreen(scannedDraft: draft),
        ),
      ),
    );
    await tester.tap(find.text('Read from image'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Get on-device song AI?'), findsOneWidget);
    expect(scanService.downloadCalls, 0);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(scanService.downloadCalls, 1);
    expect(find.textContaining('organized on this device'), findsOneWidget);
  });

  testWidgets('shows an identification warning and raw OCR after AI failure', (
    tester,
  ) async {
    const ocrText = '11:44 & @ © ue - ll > Os\nఇ నీ ప్రేమ ధార';
    const draft = ScannedSongDraft(
      title: '',
      body: ocrText,
      imagePath: '/missing/test-photo.jpg',
      aiFallback: true,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CustomSongEditorScreen(scannedDraft: draft)),
      ),
    );
    await tester.pump();

    expect(find.text('Couldn’t identify a song'), findsOneWidget);
    expect(find.textContaining('The OCR text is shown below'), findsOneWidget);
    expect(find.text(ocrText), findsOneWidget);
    expect(find.text('Enter the song title'), findsOneWidget);
  });
}

class _FakeSongScanService implements SongScanService {
  _FakeSongScanService({this.status = OnDeviceAiStatus.available});

  final OnDeviceAiStatus status;
  var recognizeCalls = 0;
  var downloadCalls = 0;

  @override
  Future<String> recognize(String imagePath) async {
    recognizeCalls++;
    return 'తెలుగు పాట శీర్షిక\nమొదటి పాట పంక్తి';
  }

  @override
  Future<OnDeviceAiStatus> getAiStatus() async => status;

  @override
  Future<void> downloadAiModel() async {
    downloadCalls++;
  }

  @override
  Future<ScannedSongDraft> structure(String recognizedText) async {
    return const ScannedSongDraft(
      title: 'తెలుగు పాట శీర్షిక',
      englishTitle: 'Telugu Paata Sheershika',
      body: 'తెలుగు పాట శీర్షిక\nమొదటి పాట పంక్తి',
      englishBody: 'Telugu paata sheershika\nModati paata pankthi',
      aiEnhanced: true,
    );
  }
}
