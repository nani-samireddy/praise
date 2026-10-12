import 'dart:io';

import 'package:drift/native.dart';
import 'package:praise/features/custom_songs/data/custom_song_image_store.dart';
import 'package:praise/features/songs/data/song_repository.dart';
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

  test('isolates create and edit drafts across store instances', () async {
    const draft = LocalSongDraft(
      title: 'తెలుగు',
      englishTitle: '',
      body: 'Lyrics',
      englishBody: '',
      author: '',
      maleVideoUrl: '',
      femaleVideoUrl: '',
      imagePath: null,
      detailsExpanded: false,
      baseUpdatedAt: '2026-10-12T00:00:00.000Z',
    );
    await store.save(draft);
    await store.save(draft, songId: 'custom-one');
    await store.save(draft, songId: 'custom-two');
    final reopened = LocalSongDraftStore(database);
    expect(await reopened.load(songId: 'custom-one'), draft);
    await reopened.clear(songId: 'custom-one');
    expect(await reopened.load(songId: 'custom-one'), isNull);
    expect(await reopened.load(songId: 'custom-two'), draft);
    expect(await reopened.load(), draft);
  });

  test('photo cleanup respects saved songs and other drafts', () async {
    final images = _Images();
    final repository = DriftSongRepository(database, imageStore: images);
    final id = await repository.createCustomSong(
      const SongInput(title: 'Photo', body: '', newImagePath: '/photo'),
    );
    final song = await (database.select(
      database.songs,
    )..where((row) => row.id.equals(id))).getSingle();
    final draft = LocalSongDraft(
      title: 'Photo',
      englishTitle: '',
      body: '',
      englishBody: '',
      author: '',
      maleVideoUrl: '',
      femaleVideoUrl: '',
      imagePath: song.imagePath,
      detailsExpanded: false,
    );
    await store.save(draft, songId: id);
    await repository.updateCustomSong(
      id,
      const SongInput(title: 'Photo', body: 'Text', removeImage: true),
    );
    expect(images.deleted, isEmpty);
    await store.save(draft, songId: 'other');
    await store.clear(songId: id);
    await store.deleteUnreferencedImage(song.imagePath, imageStore: images);
    expect(images.deleted, isEmpty);
    await store.clear(songId: 'other');
    await store.deleteUnreferencedImage(song.imagePath, imageStore: images);
    expect(images.deleted, [song.imagePath]);
  });

  test(
    'rapid repeated saves reject stale revision and deleted songs',
    () async {
      final repository = DriftSongRepository(database);
      final id = await repository.createCustomSong(
        const SongInput(title: 'Song', body: 'Original'),
      );
      final song = await (database.select(
        database.songs,
      )..where((row) => row.id.equals(id))).getSingle();
      await repository.updateCustomSong(
        id,
        SongInput(
          title: 'Song',
          body: 'New',
          expectedUpdatedAt: song.updatedAt,
        ),
      );
      await expectLater(
        repository.updateCustomSong(
          id,
          SongInput(
            title: 'Song',
            body: 'Stale',
            expectedUpdatedAt: song.updatedAt,
          ),
        ),
        throwsStateError,
      );
      expect(
        (await (database.select(
          database.songs,
        )..where((row) => row.id.equals(id))).getSingle()).body,
        'New',
      );
      await repository.deleteCustomSong(id);
      await expectLater(
        repository.updateCustomSong(
          id,
          const SongInput(title: 'Song', body: 'Edit'),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'edit draft survives closing and reopening the local database',
    () async {
      final directory = await Directory.systemTemp.createTemp('praise-draft-');
      final file = File('${directory.path}/draft.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      const draft = LocalSongDraft(
        title: 'Restart draft',
        englishTitle: '',
        body: 'తెలుగు',
        englishBody: '',
        author: '',
        maleVideoUrl: '',
        femaleVideoUrl: '',
        imagePath: '/retained-photo',
        detailsExpanded: true,
        baseUpdatedAt: '2026-10-12T00:00:00.000Z',
      );
      try {
        await LocalSongDraftStore(original)
            .save(draft, songId: 'custom-restart');
      } finally {
        await original.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          await LocalSongDraftStore(reopened).load(songId: 'custom-restart'),
          draft,
        );
        expect(await LocalSongDraftStore(reopened).load(), isNull);
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    },
  );

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

class _Images implements CustomSongImageStore {
  final deleted = <String>[];
  @override
  Future<String> save(String sourcePath) async => '$sourcePath-copy';
  @override
  Future<void> delete(String storedPath) async => deleted.add(storedPath);
}
