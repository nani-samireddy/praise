import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_repository.dart';
import 'package:praise/features/custom_songs/data/local_song_draft.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';
import 'package:praise/features/custom_songs/data/song_scan_service.dart';
import 'package:praise/features/custom_songs/presentation/custom_song_editor_screen.dart';

void main() {
  late AppDatabase testDatabase;
  setUp(() => testDatabase = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => testDatabase.close());
  testWidgets(
    'edit recovery requires restore and discard preserves saved song',
    (tester) async {
      final database = testDatabase;
      final repository = DriftSongRepository(database);
      final id = await repository.createCustomSong(
        const SongInput(title: 'Saved song', body: 'Saved lyrics'),
      );
      final song = await (database.select(
        database.songs,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final store = LocalSongDraftStore(database);
      await store.save(
        LocalSongDraft(
          title: 'Unfinished edit',
          englishTitle: '',
          body: 'Draft lyrics',
          englishBody: '',
          author: '',
          maleVideoUrl: '',
          femaleVideoUrl: '',
          imagePath: null,
          detailsExpanded: false,
          baseUpdatedAt: song!.updatedAt.toIso8601String(),
        ),
        songId: id,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(home: CustomSongEditorScreen(songId: id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restore unfinished edits?'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Unfinished edit'),
        findsOneWidget,
      );
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Saved song'), findsOneWidget);
      expect(await store.load(songId: id), isNull);
      expect(
        (await (database.select(
          database.songs,
        )..where((row) => row.id.equals(id))).getSingleOrNull())!.body,
        'Saved lyrics',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed stale save retains edit draft and newer saved lyrics', (
    tester,
  ) async {
    final database = testDatabase;
    final repository = DriftSongRepository(database);
    final id = await repository.createCustomSong(
      const SongInput(title: 'Song', body: 'Original'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: CustomSongEditorScreen(songId: id)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lyrics'),
      'Unfinished lyrics',
    );
    await tester.pumpAndSettle();
    await repository.updateCustomSong(
      id,
      const SongInput(title: 'Song', body: 'Newer saved lyrics'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save song'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t save. The song'), findsOneWidget);
    expect(
      (await LocalSongDraftStore(database).load(songId: id))!.body,
      'Unfinished lyrics',
    );
    expect(
      (await (database.select(
        database.songs,
      )..where((row) => row.id.equals(id))).getSingleOrNull())!.body,
      'Newer saved lyrics',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'successful edit clears only its draft and permits another edit',
    (tester) async {
      final repository = DriftSongRepository(testDatabase);
      final id = await repository.createCustomSong(
        const SongInput(title: 'Song', body: 'Original'),
      );
      final store = LocalSongDraftStore(testDatabase);
      const createDraft = LocalSongDraft(
        title: 'New draft',
        englishTitle: '',
        body: 'New lyrics',
        englishBody: '',
        author: '',
        maleVideoUrl: '',
        femaleVideoUrl: '',
        imagePath: null,
        detailsExpanded: false,
      );
      await store.save(createDraft);
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (_, _) => CustomSongEditorScreen(songId: id),
          ),
          GoRoute(
            path: '/songs/:id',
            builder: (_, _) => const Scaffold(body: Text('Saved destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(testDatabase)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lyrics'),
        'First edit',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save song'));
      await tester.pumpAndSettle();
      expect(find.text('Saved destination'), findsOneWidget);
      expect(await store.load(songId: id), isNull);
      expect(await store.load(), createDraft);
      router.go('/edit');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'First edit'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lyrics'),
        'Second edit',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save song'));
      await tester.pumpAndSettle();
      expect(find.text('Saved destination'), findsOneWidget);
      expect(await store.load(songId: id), isNull);
      expect(
        (await (testDatabase.select(
          testDatabase.songs,
        )..where((row) => row.id.equals(id))).getSingle()).body,
        'Second edit',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('back navigation keeps edit draft for explicit recovery', (
    tester,
  ) async {
    final id = await DriftSongRepository(testDatabase)
        .createCustomSong(const SongInput(title: 'Song', body: 'Saved'));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit'),
              child: const Text('Open editor'),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => CustomSongEditorScreen(songId: id),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lyrics'),
      'Unfinished back edit',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open editor'), findsOneWidget);
    expect(
      (await LocalSongDraftStore(testDatabase).load(songId: id))!.body,
      'Unfinished back edit',
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    expect(find.text('Restore unfinished edits?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Unfinished back edit'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'extraction failure preserves existing fields and retained photo',
    (tester) async {
      final scanService = _FakeSongScanService(failRecognition: true);
      const draft = ScannedSongDraft(
        title: 'Keep title',
        body: 'Keep lyrics',
        imagePath: '/missing/retained.jpg',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDatabase),
            songScanServiceProvider.overrideWithValue(scanService),
          ],
          child: const MaterialApp(
            home: CustomSongEditorScreen(scannedDraft: draft),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read from image'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Keep title'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Keep lyrics'), findsOneWidget);
      expect(find.text('Original photo'), findsOneWidget);
      expect(
        (await LocalSongDraftStore(testDatabase).load())!.imagePath,
        draft.imagePath,
      );
    },
  );

  testWidgets('starts manual entry with only the essential fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase)],
        child: MaterialApp(home: CustomSongEditorScreen()),
      ),
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
    final database = testDatabase;
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
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase)],
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
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase)],
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
        overrides: [
          databaseProvider.overrideWithValue(testDatabase),
          songScanServiceProvider.overrideWithValue(scanService),
        ],
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
        overrides: [
          databaseProvider.overrideWithValue(testDatabase),
          songScanServiceProvider.overrideWithValue(scanService),
        ],
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
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDatabase)],
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
  _FakeSongScanService({
    this.status = OnDeviceAiStatus.available,
    this.failRecognition = false,
  });

  final bool failRecognition;

  final OnDeviceAiStatus status;
  var recognizeCalls = 0;
  var downloadCalls = 0;

  @override
  Stream<String> get aiProgress => const Stream.empty();

  @override
  Future<String> recognize(String imagePath) async {
    recognizeCalls++;
    if (failRecognition) throw StateError('Extraction denied or unavailable');
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
