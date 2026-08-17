import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../data/github_feedback_service.dart';

enum FeedbackFormType { songRequest, problemReport, songCorrection }

Future<void> showFeedbackForm({
  required BuildContext context,
  required GithubFeedbackService service,
  required FeedbackFormType type,
  Song? song,
}) async {
  final receipt = await showModalBottomSheet<GithubIssueReceipt>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _FeedbackFormSheet(service: service, type: type, song: song),
  );
  if (receipt == null || !context.mounted) return;
  await _showReceipt(context, service, receipt);
}

class _FeedbackFormSheet extends StatefulWidget {
  const _FeedbackFormSheet({
    required this.service,
    required this.type,
    required this.song,
  });

  final GithubFeedbackService service;
  final FeedbackFormType type;
  final Song? song;

  @override
  State<_FeedbackFormSheet> createState() => _FeedbackFormSheetState();
}

class _FeedbackFormSheetState extends State<_FeedbackFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _thirdController = TextEditingController();
  final _fourthController = TextEditingController();
  final _fifthController = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _thirdController.dispose();
    _fourthController.dispose();
    _fifthController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final receipt = await switch (widget.type) {
        FeedbackFormType.songRequest => widget.service.requestSong(
          title: _primaryController.text,
          englishTitle: _secondaryController.text,
          author: _thirdController.text,
          lyricsOrSource: _fourthController.text,
          notes: _fifthController.text,
        ),
        FeedbackFormType.problemReport => widget.service.reportProblem(
          summary: _primaryController.text,
          description: _secondaryController.text,
          steps: _thirdController.text,
          deviceDetails: _fourthController.text,
        ),
        FeedbackFormType.songCorrection => widget.service.reportSong(
          song: widget.song!,
          correction: _primaryController.text,
          suggestedCorrectionOrSource: _secondaryController.text,
        ),
      };
      if (!mounted) return;
      Navigator.pop(context, receipt);
    } on FeedbackSubmissionException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not submit right now. Try again later.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Material(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.song case final song?) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.music_note_outlined),
                      title: Text(song.title),
                      subtitle: Text('Catalogue ID: ${song.id}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ..._fields,
                const SizedBox(height: 16),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.public_outlined, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Submitting creates a public GitHub issue through the '
                        'Praise support service. Do not include private information.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_submitting ? 'Submitting…' : 'Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (widget.type) {
    FeedbackFormType.songRequest => 'Request a song',
    FeedbackFormType.problemReport => 'Report a problem',
    FeedbackFormType.songCorrection => 'Report this song',
  };

  List<Widget> get _fields => switch (widget.type) {
    FeedbackFormType.songRequest => [
      _field(_primaryController, 'Song title', required: true),
      _gap,
      _field(_secondaryController, 'English title', hint: 'Optional'),
      _gap,
      _field(_thirdController, 'Author or source', hint: 'Optional'),
      _gap,
      _field(
        _fourthController,
        'Lyrics or source link',
        required: true,
        multiline: true,
      ),
      _gap,
      _field(_fifthController, 'Additional notes', multiline: true),
    ],
    FeedbackFormType.problemReport => [
      _field(_primaryController, 'Short summary', required: true),
      _gap,
      _field(
        _secondaryController,
        'What happened?',
        required: true,
        multiline: true,
      ),
      _gap,
      _field(_thirdController, 'Steps to reproduce', multiline: true),
      _gap,
      _field(_fourthController, 'Device and Android version', hint: 'Optional'),
    ],
    FeedbackFormType.songCorrection => [
      _field(
        _primaryController,
        'What should be corrected?',
        required: true,
        multiline: true,
      ),
      _gap,
      _field(
        _secondaryController,
        'Suggested correction or source',
        multiline: true,
      ),
    ],
  };

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
    bool multiline = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 8 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  static const _gap = SizedBox(height: 14);
}

Future<void> _showReceipt(
  BuildContext context,
  GithubFeedbackService service,
  GithubIssueReceipt receipt,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
      title: Text('Issue #${receipt.number} created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Keep this link to track updates:'),
          const SizedBox(height: 10),
          SelectableText(receipt.url.toString()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: receipt.url.toString()),
            );
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(
              dialogContext,
            ).showSnackBar(const SnackBar(content: Text('Issue link copied.')));
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy link'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await service.openIssue(receipt);
            } catch (_) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Could not open the issue link.')),
              );
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open issue'),
        ),
      ],
    ),
  );
}
