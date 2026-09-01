import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/network_providers.dart';

class GithubIssueReceipt {
  const GithubIssueReceipt({required this.number, required this.url});

  final int number;
  final Uri url;
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class GithubFeedbackService {
  Future<GithubIssueReceipt> requestSong({
    required String title,
    String? englishTitle,
    String? author,
    required String lyricsOrSource,
    String? notes,
  });

  Future<GithubIssueReceipt> reportProblem({
    required String summary,
    required String description,
    String? steps,
    String? deviceDetails,
  });

  Future<GithubIssueReceipt> reportSong({
    required Song song,
    required String correction,
    String? suggestedCorrectionOrSource,
  });

  Future<void> openIssue(GithubIssueReceipt receipt);
}

class ApiGithubFeedbackService implements GithubFeedbackService {
  const ApiGithubFeedbackService({required this.dio, required this.endpoint});

  final Dio dio;
  final String endpoint;

  @override
  Future<GithubIssueReceipt> requestSong({
    required String title,
    String? englishTitle,
    String? author,
    required String lyricsOrSource,
    String? notes,
  }) {
    return _submit({
      'kind': 'song_request',
      'title': _required(title, 'Song title'),
      'englishTitle': _optional(englishTitle),
      'author': _optional(author),
      'lyricsOrSource': _required(lyricsOrSource, 'Lyrics or source'),
      'notes': _optional(notes),
    });
  }

  @override
  Future<GithubIssueReceipt> reportProblem({
    required String summary,
    required String description,
    String? steps,
    String? deviceDetails,
  }) {
    return _submit({
      'kind': 'problem_report',
      'summary': _required(summary, 'Summary'),
      'description': _required(description, 'Description'),
      'steps': _optional(steps),
      'deviceDetails': _optional(deviceDetails),
    });
  }

  @override
  Future<GithubIssueReceipt> reportSong({
    required Song song,
    required String correction,
    String? suggestedCorrectionOrSource,
  }) {
    return _submit({
      'kind': 'song_correction',
      'songId': song.id,
      'songTitle': song.title,
      'songEnglishTitle': _optional(song.englishTitle),
      'correction': _required(correction, 'Correction details'),
      'suggestedCorrectionOrSource': _optional(suggestedCorrectionOrSource),
    });
  }

  @override
  Future<void> openIssue(GithubIssueReceipt receipt) async {
    final opened = await launchUrl(
      receipt.url,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const FeedbackSubmissionException(
        'The issue was created, but its link could not be opened.',
      );
    }
  }

  Future<GithubIssueReceipt> _submit(Map<String, Object?> payload) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.scheme != 'https') {
      throw const FeedbackSubmissionException(
        'Feedback is not configured in this build.',
      );
    }
    try {
      final response = await dio.postUri<Map<String, Object?>>(
        uri,
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
          headers: const {'Content-Type': 'application/json'},
        ),
      );
      final data = response.data;
      final number = data?['number'];
      final url = Uri.tryParse(data?['url'] as String? ?? '');
      if (number is! int || url == null || url.scheme != 'https') {
        throw const FeedbackSubmissionException(
          'The support service returned an invalid response.',
        );
      }
      return GithubIssueReceipt(number: number, url: url);
    } on FeedbackSubmissionException {
      rethrow;
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map<String, Object?>
          ? responseData['message'] as String?
          : null;
      throw FeedbackSubmissionException(
        message ?? 'Could not submit right now. Try again in a minute.',
      );
    } on Object {
      throw const FeedbackSubmissionException(
        'Could not submit right now. Try again later.',
      );
    }
  }

  static String _required(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FeedbackSubmissionException('$fieldName is required.');
    }
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final githubFeedbackServiceProvider = Provider<GithubFeedbackService>((ref) {
  return ApiGithubFeedbackService(
    dio: ref.watch(dioProvider),
    endpoint: AppConfig.feedbackApiUrl,
  );
});
