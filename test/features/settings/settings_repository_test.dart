import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/core/database/app_database.dart';
import 'package:praise/features/settings/data/settings_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftSettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('uses reading defaults and persists updated settings', () async {
    expect(await repository.watchThemeMode().first, isNull);
    expect(await repository.watchLyricsFontSize().first, 19);
    expect(
      await repository.watchLyricsDisplayMode().first,
      LyricsDisplayMode.both,
    );

    await repository.setThemeMode('dark');
    await repository.setLyricsFontSize(27.5);
    await repository.setLyricsDisplayMode(LyricsDisplayMode.english);

    final reopenedRepository = DriftSettingsRepository(database);
    expect(await reopenedRepository.watchThemeMode().first, 'dark');
    expect(await reopenedRepository.watchLyricsFontSize().first, 27.5);
    expect(
      await reopenedRepository.watchLyricsDisplayMode().first,
      LyricsDisplayMode.english,
    );
  });

  test('clamps saved lyrics sizes to the readable range', () async {
    await repository.setLyricsFontSize(100);
    expect(await repository.watchLyricsFontSize().first, 38);

    await repository.setLyricsFontSize(2);
    expect(await repository.watchLyricsFontSize().first, 16);
  });
}
