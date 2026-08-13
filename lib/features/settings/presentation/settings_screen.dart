import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _draftFontSize;

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final storedFontSize = ref.watch(lyricsFontSizeProvider).valueOrNull ?? 19;
    final fontSize = _draftFontSize ?? storedFontSize;
    final displayMode =
        ref.watch(lyricsDisplayModeProvider).valueOrNull ??
        LyricsDisplayMode.both;

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
                      Text('${fontSize.round()} px'),
                    ],
                  ),
                  Slider(
                    value: fontSize,
                    min: 16,
                    max: 38,
                    divisions: 22,
                    label: '${fontSize.round()} px',
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
                    'Display language',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<LyricsDisplayMode>(
                    segments: const [
                      ButtonSegment(
                        value: LyricsDisplayMode.primary,
                        label: Text('Primary'),
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
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Offline catalogue'),
              subtitle: Text(
                'Manual server refresh will be added in the sync phase.',
              ),
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
