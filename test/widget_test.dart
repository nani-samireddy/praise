import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/app/app.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_repository.dart';
import 'package:praise/features/songs/presentation/song_providers.dart';

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository(song)),
        ],
        child: const PraiseApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('ప్రార్థన గీతం'), findsOneWidget);
    expect(find.text('Prayer Song'), findsOneWidget);

    await tester.tap(find.text('ప్రార్థన గీతం'));
    await _pumpFrames(tester);

    expect(find.text('ప్రధాన గీతము'), findsOneWidget);
    expect(find.text('Primary English lyrics'), findsOneWidget);
    expect(find.text('Test Author'), findsOneWidget);
  });
}

class _FakeSongRepository implements SongRepository {
  const _FakeSongRepository(this.song);

  final Song song;

  @override
  Stream<Song?> watchSong(String id) =>
      Stream.value(id == song.id ? song : null);

  @override
  Stream<List<Song>> watchSongs({String search = ''}) => Stream.value([song]);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
