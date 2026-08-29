import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../catalogue_sync/presentation/catalogue_sync_feedback.dart';
import '../../catalogue_sync/presentation/catalogue_sync_providers.dart';
import '../../feedback/data/github_feedback_service.dart';
import '../../feedback/presentation/feedback_dialogs.dart';
import '../data/settings_repository.dart';
import '../data/telugu_font.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _draftFontSize;

  Future<void> _refreshCatalogue() async {
    try {
      final result = await ref
          .read(catalogueSyncControllerProvider.notifier)
          .sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(catalogueSyncSuccessMessage(result))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(catalogueSyncErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final storedFontSize = ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final fontSize = _draftFontSize ?? storedFontSize;
    final displayMode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;
    final teluguFont =
        ref.watch(teluguFontProvider).valueOrNull ?? TeluguFont.system;
    final syncState = ref.watch(catalogueSyncControllerProvider);
    final catalogueStatus = ref.watch(catalogueStatusProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.phone_android),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => ref
                        .read(settingsRepositoryProvider)
                        .setThemeMode(selection.single.name),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Lyrics'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Default text size',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${fontSize.round()}'),
                    ],
                  ),
                  Slider(
                    value: fontSize,
                    min: 16,
                    max: 38,
                    divisions: 22,
                    label: '${fontSize.round()}',
                    semanticFormatterCallback: (value) =>
                        'Text size ${value.round()}',
                    onChanged: (value) =>
                        setState(() => _draftFontSize = value),
                    onChangeEnd: (value) async {
                      await ref
                          .read(settingsRepositoryProvider)
                          .setLyricsFontSize(value);
                      if (mounted) setState(() => _draftFontSize = null);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => ref
                          .read(settingsRepositoryProvider)
                          .setLyricsFontSize(19),
                      child: const Text('Reset'),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Telugu typeface',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TeluguFont>(
                    key: ValueKey(teluguFont),
                    initialValue: teluguFont,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.font_download_outlined),
                    ),
                    items: [
                      for (final font in TeluguFont.values)
                        DropdownMenuItem(
                          value: font,
                          child: Text(
                            '${font.label}  •  తెలుగు',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: font.fontFamily),
                          ),
                        ),
                    ],
                    onChanged: (font) {
                      if (font == null) return;
                      ref.read(settingsRepositoryProvider).setTeluguFont(font);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'ఆరాధన • యేసు నామం • స్తోత్ర గీతం',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: teluguFont.fontFamily,
                        fontSize: 21,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Display language',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<LyricsDisplayMode>(
                    segments: const [
                      ButtonSegment(
                        value: LyricsDisplayMode.primary,
                        label: Text('Original'),
                      ),
                      ButtonSegment(
                        value: LyricsDisplayMode.english,
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: LyricsDisplayMode.both,
                        label: Text('Both'),
                      ),
                    ],
                    selected: {displayMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => ref
                        .read(settingsRepositoryProvider)
                        .setLyricsDisplayMode(selection.single),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Catalogue'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_download_outlined),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline catalogue',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _catalogueStatusText(
                            catalogueStatus?.catalogueVersion,
                            catalogueStatus?.lastSuccessfulSync,
                          ),
                        ),
                        if (!AppConfig.isCatalogueSyncConfigured) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Remote refresh is not configured in this build.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (syncState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton.filledTonal(
                      onPressed: AppConfig.isCatalogueSyncConfigured
                          ? _refreshCatalogue
                          : null,
                      tooltip: 'Refresh catalogue',
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Feedback & requests'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_add_outlined),
                  title: const Text('Request a song'),
                  subtitle: const Text('Submit and receive a tracking link'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showFeedbackForm(
                    context: context,
                    service: ref.read(githubFeedbackServiceProvider),
                    type: FeedbackFormType.songRequest,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Report a problem'),
                  subtitle: const Text('Submit and receive a tracking link'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showFeedbackForm(
                    context: context,
                    service: ref.read(githubFeedbackServiceProvider),
                    type: FeedbackFormType.problemReport,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('About'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Praise'),
              subtitle: Text('Version 1.0.0 • Offline-first lyrics'),
            ),
          ),
        ],
      ),
    );
  }
}

String _catalogueStatusText(int? version, DateTime? lastSync) {
  if (lastSync == null) return 'Bundled songs are available offline.';
  final local = lastSync.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final versionText = version == null ? '' : 'Version $version • ';
  return '$versionText last refreshed $date at $time';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
