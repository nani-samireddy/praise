import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/custom_songs/data/local_song_draft.dart';

void main() {
  late AppDatabase database;
  late LocalSongDraftStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalSongDraftStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and restores an unfinished song draft', () async {
    const draft = LocalSongDraft(
      title: 'అంతా నాలోనే',
      englishTitle: 'Everything in me',
      body: 'చరణం',
      englishBody: 'Verse',
      author: 'Test author',
      maleVideoUrl: 'https://example.com/male',
      femaleVideoUrl: 'https://example.com/female',
      imagePath: '/tmp/song.png',
      detailsExpanded: true,
    );

    await store.save(draft);

    expect(await store.load(), equals(draft));
  });

  test('clears the draft without affecting other metadata', () async {
    const draft = LocalSongDraft(
      title: 'Draft',
      englishTitle: '',
      body: '',
      englishBody: '',
      author: '',
      maleVideoUrl: '',
      femaleVideoUrl: '',
      imagePath: null,
      detailsExpanded: false,
    );

    await store.save(draft);
    await store.clear();

    expect(await store.load(), isNull);
  });
}
