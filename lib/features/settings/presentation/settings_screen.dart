import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../catalogue_sync/presentation/catalogue_sync_feedback.dart';
import '../../catalogue_sync/presentation/catalogue_sync_progress_view.dart';
import '../../catalogue_sync/presentation/catalogue_sync_providers.dart';
import '../../feedback/data/github_feedback_service.dart';
import '../../feedback/presentation/feedback_dialogs.dart';
import '../data/settings_repository.dart';
import '../data/telugu_font.dart';
import 'settings_providers.dart';
import 'feature_providers.dart';
import '../data/feature_flags.dart';

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
    final syncProgress = ref.watch(catalogueSyncProgressProvider);
    final catalogueStatus = ref.watch(catalogueStatusProvider).valueOrNull;
    final catalogueSyncEnabled =
        ref
            .watch(featureEnabledProvider(FeatureKey.catalogueSync))
            .valueOrNull ??
        true;

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
          const _SectionTitle('Your preferences'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Your role'),
              subtitle: Text(
                ref.watch(primaryRoleProvider).valueOrNull?.name ??
                    'Choose a role to personalize your features',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/starter?change=true'),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Features'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < featureDefinitions.length; i++) ...[
                  _FeatureTile(definition: featureDefinitions[i]),
                  if (i < featureDefinitions.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                          'Text size',
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
                    'Telugu font',
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
                    'Lyrics language',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<LyricsDisplayMode>(
                      segments: const [
                        ButtonSegment(
                          value: LyricsDisplayMode.primary,
                          label: Text('Original only'),
                        ),
                        ButtonSegment(
                          value: LyricsDisplayMode.english,
                          label: Text('English only'),
                        ),
                        ButtonSegment(
                          value: LyricsDisplayMode.both,
                          label: Text('Sections'),
                        ),
                        ButtonSegment(
                          value: LyricsDisplayMode.lineByLine,
                          label: Text('Line by line'),
                        ),
                      ],
                      selected: {displayMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => ref
                          .read(settingsRepositoryProvider)
                          .setLyricsDisplayMode(selection.single),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Song library'),
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
                          'Song library',
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
                            'Song updates aren’t available in this build.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (!catalogueSyncEnabled)
                          Text(
                            'Song updates are turned off in Features.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (syncProgress != null)
                          CatalogueSyncProgressView(
                            progress: syncProgress,
                            compact: true,
                          ),
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
                      onPressed:
                          catalogueSyncEnabled &&
                              AppConfig.isCatalogueSyncConfigured
                          ? _refreshCatalogue
                          : null,
                      tooltip: 'Refresh songs',
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Help & feedback'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_add_outlined),
                  title: const Text('Request a song'),
                  subtitle: const Text('Tell us which song to add'),
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
                  subtitle: const Text('Tell us what went wrong'),
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
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Praise'),
                  subtitle: Text('Version 1.0.0 • Offline-first lyrics'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  subtitle: const Text('Local storage, camera, and feedback'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacyDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy'),
        content: const SingleChildScrollView(
          child: Text(
            'Praise is offline-first. Songs, favorites, lists, custom lyrics, '
            'and saved song photos are stored on this device.\n\n'
            'Camera and photo access are used only when you choose to scan or '
            'keep a song photo. Text recognition runs on the device where supported.\n\n'
            'The app connects to the internet to update the public song '
            'song library, open YouTube practice videos, open shared list links, '
            'and submit feedback or song requests. Feedback submissions may '
            'become reviewer-visible support requests, so do not include private details.\n\n'
            'Songs in the library are community-provided. Praise does not intend to '
            'use anyone\'s work without permission. If your work appears in '
            'the song library without consent, report the song and it will be '
            'reviewed for removal.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({required this.definition});
  final FeatureDefinition definition;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = definition.available
        ? (ref.watch(featureEnabledProvider(definition.key)).valueOrNull ??
              true)
        : false;
    return SwitchListTile(
      secondary: Icon(
        definition.available ? Icons.toggle_on_outlined : Icons.hourglass_empty,
      ),
      title: Text(definition.label),
      subtitle: Text(
        definition.available
            ? definition.description
            : '${definition.description} • Not available yet',
      ),
      value: enabled,
      onChanged: definition.available
          ? (value) => ref
                .read(featureSettingsStoreProvider)
                .set(
                  ref.read(featureSettingsStoreProvider).key(definition.key),
                  value.toString(),
                )
          : null,
    );
  }
}

String _catalogueStatusText(int? version, DateTime? lastSync) {
  if (lastSync == null) return 'Songs are available offline.';
  final local = lastSync.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final versionText = version == null ? '' : 'Version $version • ';
  return '${versionText}Last updated $date at $time';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
