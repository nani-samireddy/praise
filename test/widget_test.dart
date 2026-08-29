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
      source: 'server',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );
    final sharingService = _FakeSongSharingService();
    final feedbackService = _FakeGithubFeedbackService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository(song)),
          songSharingServiceProvider.overrideWithValue(sharingService),
          githubFeedbackServiceProvider.overrideWithValue(feedbackService),
          favoritesRepositoryProvider.overrideWithValue(
            const _FakeFavoritesRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            const _FakeSettingsRepository(),
          ),
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
    expect(find.text('Test Author'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(song.body)).style?.fontFamily,
      TeluguFont.notoSansTelugu.fontFamily,
    );

    await tester.tap(find.byTooltip('Share song'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Copy text'));
    await _pumpFrames(tester);
    expect(sharingService.copiedSong, song);
    expect(find.text('Song copied.'), findsOneWidget);

    await tester.tap(find.byTooltip('Share song'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share text'));
    await _pumpFrames(tester);
    expect(sharingService.sharedSong, song);

    await tester.tap(find.byTooltip('Share song'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share image'));
    await _pumpFrames(tester);
    expect(sharingService.sharedImageSong, song);

    await tester.tap(find.byTooltip('Share song'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Share PDF'));
    await _pumpFrames(tester);
    expect(sharingService.sharedPdfSong, song);

    await tester.tap(find.byTooltip('More options'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Report this song'));
    await _pumpFrames(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What should be corrected?'),
      'The second line is incorrect.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await _pumpFrames(tester);
    expect(feedbackService.reportedSong, song);
    expect(find.text('Issue #77 created'), findsOneWidget);
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
    url: Uri.parse('https://github.com/example/issues/77'),
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
  const _FakeSettingsRepository();

  @override
  Future<void> setLyricsDisplayMode(LyricsDisplayMode value) async {}

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
