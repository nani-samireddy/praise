import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/feedback/data/github_feedback_service.dart';

void main() {
  late Dio dio;
  late _FakeHttpClientAdapter adapter;
  late GithubFeedbackService service;

  setUp(() {
    dio = Dio();
    adapter = _FakeHttpClientAdapter();
    dio.httpClientAdapter = adapter;
    service = ApiGithubFeedbackService(
      dio: dio,
      endpoint: 'https://support.example.test/v1/issues',
    );
  });

  tearDown(() => dio.close(force: true));

  test('submits a song request and returns its tracking link', () async {
    final receipt = await service.requestSong(
      title: '  New song  ',
      lyricsOrSource: ' https://example.test/song ',
    );

    expect(adapter.lastData, {
      'kind': 'song_request',
      'title': 'New song',
      'englishTitle': null,
      'author': null,
      'lyricsOrSource': 'https://example.test/song',
      'notes': null,
    });
    expect(receipt.number, 42);
    expect(receipt.url.toString(), 'https://discord.com/channels/1/2/42');
  });

  test('includes the catalogue identity in a song correction', () async {
    final now = DateTime.utc(2026, 8, 15);
    final song = Song(
      id: 'song-123',
      title: 'యేసు & నా పాట',
      englishTitle: 'Jesus & My Song',
      body: 'Lyrics',
      englishBody: null,
      author: null,
      source: 'server',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );

    await service.reportSong(song: song, correction: 'Fix line two');

    expect(adapter.lastData?['kind'], 'song_correction');
    expect(adapter.lastData?['songId'], 'song-123');
    expect(adapter.lastData?['songTitle'], 'యేసు & నా పాట');
    expect(adapter.lastData?['correction'], 'Fix line two');
  });

  test('rejects empty required fields before sending', () async {
    expect(
      () => service.reportProblem(summary: '', description: 'Details'),
      throwsA(isA<FeedbackSubmissionException>()),
    );
    expect(adapter.lastData, isNull);
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  Map<String, Object?>? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastData = (options.data as Map).cast<String, Object?>();
    return ResponseBody.fromString(
      jsonEncode({'number': 42, 'url': 'https://discord.com/channels/1/2/42'}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
