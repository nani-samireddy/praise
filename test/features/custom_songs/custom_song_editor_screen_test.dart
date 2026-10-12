import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_repository.dart';
import 'package:praise/features/custom_songs/data/local_song_draft.dart';
import 'package:praise/features/custom_songs/data/scanned_song_draft.dart';
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

  testWidgets('keeps incoming text for manual editing without recognition UI', (
    tester,
  ) async {
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

    expect(find.text('Add a song'), findsOneWidget);
    expect(find.textContaining('organized on this device'), findsNothing);
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

  testWidgets(
    'keeps a photo with optional manual lyrics and no recognition controls',
    (tester) async {
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
      expect(find.text('Read from image'), findsNothing);
      expect(find.textContaining('Gemma'), findsNothing);
      expect(find.text('Lyrics'), findsOneWidget);
      expect(
        find.text('Optional when keeping the original photo'),
        findsOneWidget,
      );
    },
  );
}
