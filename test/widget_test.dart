import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/app/app.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/favorites/data/favorites_repository.dart';
import 'package:praise/features/favorites/presentation/favorite_providers.dart';
import 'package:praise/features/feedback/data/github_feedback_service.dart';
import 'package:praise/features/songs/data/song_repository.dart';
import 'package:praise/features/songs/data/song_sharing_service.dart';
import 'package:praise/features/songs/presentation/song_providers.dart';
import 'package:praise/features/settings/data/settings_repository.dart';
import 'package:praise/features/settings/data/telugu_font.dart';
import 'package:praise/features/settings/presentation/settings_providers.dart';

void main() {
  testWidgets('opens a locally sourced song and displays both bodies', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 13);
    final song = Song(
      id: 'test-song',
      title: 'ప్రార్థన గీతం',
      englishTitle: 'Prayer Song',
      body: 'ప్రధాన గీతము',
      englishBody: 'Primary English lyrics',
      author: 'Test Author',
      structureJson: '''
        {
          "sections": [
            {
              "label": "Verse",
              "lines": [
                {
                  "text": "ప్రధాన గీతము",
                  "segments": [
                    {"text": "ప్రధాన గీతము", "chord": "C"}
                  ]
                }
              ]
            }
          ],
          "capo": 2,
          "harmonyParts": [
            {
              "label": "Alto",
              "lines": [
                {"text": "ఆల్టో గీతము"}
              ]
            }
          ]
        }
      ''',
      source: 'server',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );
    final sharingService = _FakeSongSharingService();
    final feedbackService = _FakeGithubFeedbackService();
    final settingsRepository = _FakeSettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository(song)),
          songSharingServiceProvider.overrideWithValue(sharingService),
          githubFeedbackServiceProvider.overrideWithValue(feedbackService),
          favoritesRepositoryProvider.overrideWithValue(
            const _FakeFavoritesRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
        ],
        child: const PraiseApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('ప్రార్థన గీతం'), findsOneWidget);
    expect(find.textContaining('Prayer Song'), findsOneWidget);

    await tester.tap(find.text('ప్రార్థన గీతం'));
    await _pumpFrames(tester);

    expect(find.text('ప్రధాన గీతము'), findsOneWidget);
    expect(find.text('Primary English lyrics'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    expect(find.text('This song is authored by Test Author.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Song controls'));
    await _pumpFrames(tester);
    expect(find.text('Song controls'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Show full lyrics'), findsOneWidget);
    expect(find.text('Lyrics display'), findsOneWidget);
    expect(find.text('Chords'), findsOneWidget);
    expect(find.text('Guitar chord shapes'), findsNothing);
    expect(find.text('Harmony parts'), findsOneWidget);
    expect(find.text('Metronome'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Chords'))
          .value,
      isFalse,
    );
    await tester.tap(find.text('Chords'));
    await _pumpFrames(tester);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Chords'))
          .value,
      isTrue,
    );
    expect(find.text('Guitar chord shapes'), findsOneWidget);
    await tester.tap(find.text('Line by line'));
    await _pumpFrames(tester);
    expect(
      settingsRepository.selectedDisplayMode,
      LyricsDisplayMode.lineByLine,
    );
    await tester.ensureVisible(find.text('Hide controls'));
    await tester.tap(find.text('Hide controls'));
    await _pumpFrames(tester);
    expect(
      tester.widget<Text>(find.text(song.body)).style?.fontFamily,
      TeluguFont.notoSansTelugu.fontFamily,
    );

    await tester.tap(find.byTooltip('Share'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Copy lyrics'));
    await _pumpFrames(tester);
    expect(sharingService.copiedSong, song);
    expect(find.text('Lyrics copied.'), findsOneWidget);

    await tester.tap(find.byTooltip('Share'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share as text'));
    await _pumpFrames(tester);
    expect(sharingService.sharedSong, song);

    await tester.tap(find.byTooltip('Share'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share as image'));
    await _pumpFrames(tester);
    expect(sharingService.sharedImageSong, song);

    await tester.tap(find.byTooltip('Share'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share as PDF'));
    await _pumpFrames(tester);
    expect(sharingService.sharedPdfSong, song);

    await tester.tap(find.byTooltip('More options'));
    await _pumpFrames(tester);
    expect(find.text('Metronome'), findsNothing);
    expect(find.text('Transpose'), findsNothing);
    expect(find.text('Lyrics view'), findsNothing);
    await tester.tap(find.text('Report a problem'));
    await _pumpFrames(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What should be corrected?'),
      'The second line is incorrect.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await _pumpFrames(tester);
    expect(feedbackService.reportedSong, song);
    expect(find.text('Request sent'), findsOneWidget);
  });
}

class _FakeGithubFeedbackService implements GithubFeedbackService {
  Song? reportedSong;

  @override
  Future<void> openIssue(GithubIssueReceipt receipt) async {}

  @override
  Future<GithubIssueReceipt> reportProblem({
    required String summary,
    required String description,
    String? steps,
    String? deviceDetails,
  }) async => _receipt;

  @override
  Future<GithubIssueReceipt> reportSong({
    required Song song,
    required String correction,
    String? suggestedCorrectionOrSource,
  }) async {
    reportedSong = song;
    return _receipt;
  }

  @override
  Future<GithubIssueReceipt> requestSong({
    required String title,
    String? englishTitle,
    String? author,
    required String lyricsOrSource,
    String? notes,
  }) async => _receipt;

  static final _receipt = GithubIssueReceipt(
    number: 77,
    url: Uri.parse('https://discord.com/channels/1/2/77'),
  );
}

class _FakeSongSharingService implements SongSharingService {
  Song? copiedSong;
  Song? sharedSong;
  Song? sharedImageSong;
  Song? sharedPdfSong;

  @override
  Future<void> copySong(Song song) async => copiedSong = song;

  @override
  Future<void> shareSong(Song song, {Rect? sharePositionOrigin}) async {
    sharedSong = song;
  }

  @override
  Future<void> shareSongImage(Song song, {Rect? sharePositionOrigin}) async {
    sharedImageSong = song;
  }

  @override
  Future<void> shareSongPdf(Song song, {Rect? sharePositionOrigin}) async {
    sharedPdfSong = song;
  }
}

class _FakeSongRepository implements SongRepository {
  const _FakeSongRepository(this.song);

  final Song song;

  @override
  Stream<Song?> watchSong(String id) =>
      Stream.value(id == song.id ? song : null);

  @override
  Stream<List<Song>> watchSongs({String search = ''}) => Stream.value([song]);

  @override
  Future<List<SongIndexEntry>> fetchSongIndexPage({
    String search = '',
    required int limit,
    required int offset,
  }) async {
    if (offset > 0) return const [];
    return [
      SongIndexEntry(
        id: song.id,
        title: song.title,
        englishTitle: song.englishTitle,
        author: song.author,
        source: song.source,
      ),
    ];
  }

  @override
  Future<String> createCustomSong(SongInput input) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCustomSong(String id) => throw UnimplementedError();

  @override
  Future<void> updateCustomSong(String id, SongInput input) =>
      throw UnimplementedError();
}

class _FakeFavoritesRepository implements FavoritesRepository {
  const _FakeFavoritesRepository();

  @override
  Future<void> setFavorite(String songId, {required bool isFavorite}) async {}

  @override
  Stream<List<Song>> watchFavorites() => Stream.value(const []);

  @override
  Stream<bool> watchIsFavorite(String songId) => Stream.value(false);
}

class _FakeSettingsRepository implements SettingsRepository {
  LyricsDisplayMode? selectedDisplayMode;

  @override
  Future<void> setLyricsDisplayMode(LyricsDisplayMode value) async {
    selectedDisplayMode = value;
  }

  @override
  Future<void> setLyricsFontSize(double value) async {}

  @override
  Future<void> setThemeMode(String value) async {}

  @override
  Future<void> setTeluguFont(TeluguFont value) async {}

  @override
  Stream<LyricsDisplayMode> watchLyricsDisplayMode() =>
      Stream.value(LyricsDisplayMode.both);

  @override
  Stream<TeluguFont> watchTeluguFont() =>
      Stream.value(TeluguFont.notoSansTelugu);

  @override
  Stream<double> watchLyricsFontSize() => Stream.value(19);

  @override
  Stream<String?> watchThemeMode() => Stream.value(null);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
