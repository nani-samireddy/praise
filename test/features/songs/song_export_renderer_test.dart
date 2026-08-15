import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/songs/data/song_export_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders bilingual song PNG and PDF exports', (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 8, 15);
      final song = Song(
        id: 'one',
        title: 'పదే పదే నేను పాడుకోనా',
        englishTitle: 'Again and Again',
        body: 'మరి మరి నే చాటుకోనా ×2',
        englishBody: 'May I proclaim it again ×2',
        author: 'Praise',
        source: 'server',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      final png = await buildSongImageBytes(song);
      final pdf = await buildSongPdfBytes(song);
      final document = buildSongExportDocument(song);

      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(document.sections, hasLength(2));
      expect(document.sections.first.body, contains('×2'));
    });
  });

  test('creates safe song export file names', () {
    expect(
      songExportFileName('Praise / Worship?', 'png'),
      'Praise - Worship-.png',
    );
  });

  testWidgets('embeds a kept song photo in PDF export', (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('praise-photo-');
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/song.png');
      await image.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
      final now = DateTime.utc(2026, 8, 15);
      final song = Song(
        id: 'photo',
        title: 'Photo song',
        englishTitle: 'Photo Song',
        body: '',
        englishBody: null,
        author: null,
        imagePath: image.path,
        source: 'custom',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      final pdf = await buildSongPdfBytes(song);

      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(pdf.length, greaterThan(1000));
    });
  });
}
