import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_sharing_service.dart';

void main() {
  test('builds readable bilingual share text without raw repeat syntax', () {
    final now = DateTime.utc(2026, 8, 14);
    final song = Song(
      id: 'share-song',
      title: 'ఆరాధన గీతం',
      englishTitle: 'Worship Song',
      body: 'మొదటి పంక్తి ×2\n\n[Repeat: ఆరాధన]',
      englishBody: '[Verse 1]\nFirst line ×2',
      author: 'Test Author',
      source: 'server',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );

    expect(buildSongShareText(song), '''ఆరాధన గీతం
Worship Song
Author: Test Author

Lyrics

మొదటి పంక్తి ×2

ఆరాధన

English lyrics

[Verse 1]

First line ×2''');
  });

  test('describes an image-only song without an empty lyrics section', () {
    final now = DateTime.utc(2026, 8, 15);
    final song = Song(
      id: 'photo-song',
      title: 'Photo song',
      englishTitle: null,
      body: '',
      englishBody: null,
      author: null,
      imagePath: '/app/photo.jpg',
      source: 'custom',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );

    expect(
      buildSongShareText(song),
      'Photo song\n\nLyrics are saved as a photo in Praise.',
    );
  });
}
