import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(databaseProvider));
});

final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchThemeMode()
      .map(
        (value) => switch (value) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      );
});

final lyricsFontSizeProvider = StreamProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).watchLyricsFontSize();
});

final lyricsDisplayModeProvider = StreamProvider<LyricsDisplayMode>((ref) {
  return ref.watch(settingsRepositoryProvider).watchLyricsDisplayMode();
});
